require "securerandom"

class RelayAT80 < Formula
  desc "Next-generation caching layer for PHP"
  homepage "https://relay.so"

  keg_only :versioned_formula

  # depends_on "concurrencykit" # v0.7.1+
  depends_on "hiredis"
  depends_on "lz4"
  depends_on "openssl"
  depends_on "php@8.0"
  depends_on "zstd"

  stable do
    url "https://github.com/cachewerk/relay.git", tag: "v0.6.4"

    resource "ext-relay" do
      if Hardware::CPU.arm?
        # stable: php8.0-darwin-arm64
        url "https://builds.r2.relay.so/v0.6.4/relay-v0.6.4-php8.0-darwin-arm64.tar.gz"
        sha256 "807527d29dd61f6c2c899060328f785533639ca12897ceea0ffb7241241f5fee"
      else
        # stable: php8.0-darwin-x86-64
        url "https://builds.r2.relay.so/v0.6.4/relay-v0.6.4-php8.0-darwin-x86-64.tar.gz"
        sha256 "f2c9672152fab8d113e6b91326413430950772296699f53a55fa9536c5367b21"
      end
    end
  end

  head do
    url "https://github.com/cachewerk/relay.git", branch: "main"

    resource "ext-relay" do
      if Hardware::CPU.arm?
        # head: php8.0-darwin-arm64
        url "https://builds.r2.relay.so/dev/relay-dev-php8.0-darwin-arm64.tar.gz"
      else
        # head: php8.0-darwin-x86-64
        url "https://builds.r2.relay.so/dev/relay-dev-php8.0-darwin-x86-64.tar.gz"
      end
    end
  end

  def conf_dir
    Pathname(Utils.safe_popen_read(Formula["php@8.0"].opt_bin/"php-config", "--ini-dir").chomp)
  end

  def install
    php = (Formula["php@8.0"].opt_bin/"php").to_s
    pecl = (Formula["php@8.0"].opt_bin/"pecl").to_s

    extensions = Utils.safe_popen_read(php, "-m")

    ["json", "igbinary", "msgpack"].each do |name|
      unless /^#{name}/.match?(extensions)
        raise "Relay requires the `#{name}` extension. Install it using `\033[32m#{pecl} install #{name}\033[0m`."
      end
    end

    resource("ext-relay").stage do
      mv "relay-pkg.so", "relay.so"
      chmod 0644, "relay.so"

      # inject UUID into binary
      `LC_ALL=C /usr/bin/sed -i '' s/00000000-0000-0000-0000-000000000000/#{SecureRandom.uuid}/ relay.so`
      `LC_ALL=C /usr/bin/sed -i '' s/BIN:31415926-5358-9793-2384-626433832795/BIN:#{SecureRandom.uuid}/ relay.so`

      # relink dependencies
      dylibs = MachO::Tools.dylibs("relay.so")

      MachO::Tools.change_install_name("relay.so",
        dylibs.grep(/libzstd/).first,
        (Formula["zstd"].opt_lib/"libzstd.dylib").to_s)

      MachO::Tools.change_install_name("relay.so",
        dylibs.grep(/liblz4/).first,
        (Formula["lz4"].opt_lib/"liblz4.dylib").to_s)

      MachO::Tools.change_install_name("relay.so",
        dylibs.grep(/libssl/).first,
        (Formula["openssl"].opt_lib/"libssl.dylib").to_s)

      MachO::Tools.change_install_name("relay.so",
        dylibs.grep(/libcrypto/).first,
        (Formula["openssl"].opt_lib/"libcrypto.dylib").to_s)

      # Apply ad-hoc code signature
      MachO.codesign!("relay.so") if Hardware::CPU.arm?

      # move extension file
      lib.install "relay.so"

      # set absolute path to extension
      inreplace "relay.ini", "extension = relay.so", "extension = #{lib}/relay.so"

      # install ini file to `etc/` (won't overwrite)
      (etc/"relay").install "relay.ini" => "relay@8.0.ini"

      # upsert absolute path to extension if `relay.ini` already existed
      inreplace etc/"relay/relay@8.0.ini", /extension\s*=.+$/, "extension = #{lib}/relay.so"

      # create ini soft link if necessary
      ln_s etc/"relay/relay@8.0.ini", conf_dir/"ext-relay.ini" unless (conf_dir/"ext-relay.ini").exist?
    end
  end

  def caveats
    <<~EOS
      The Relay extension for PHP was installed at:
        #{lib}/relay.so

      The configuration file was symlinked to:
        #{conf_dir}/ext-relay.ini

      Run `\033[32mphp --ri relay\033[0m` to ensure Relay is working.

      Finally, be sure to restart your PHP-FPM service:
        `\033[32mbrew services restart php@8.0\033[0m`
    EOS
  end
end
