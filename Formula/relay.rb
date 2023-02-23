require "securerandom"

class Relay < Formula
  desc "Next-generation caching layer for PHP"
  homepage "https://relay.so"

  # depends_on "concurrencykit" # v0.7.1+
  depends_on "hiredis"
  depends_on "lz4"
  depends_on "openssl"
  depends_on "php"
  depends_on "zstd"

  stable do
    url "https://github.com/cachewerk/relay.git", tag: "v0.6.1"

    resource "ext-relay" do
      if Hardware::CPU.arm?
        # stable: php8.2-darwin-arm64
        url "https://github.com/cachewerk/relay/releases/download/v0.6.1/relay-v0.6.1-php8.2-darwin-arm64.tar.gz"
        sha256 "6e68b100c65e549dcb23f3229ff8fff0ce0332d17fbf3cf5dceadc945696cace"
      else
        # stable: php8.2-darwin-x86-64
        url "https://github.com/cachewerk/relay/releases/download/v0.6.1/relay-v0.6.1-php8.2-darwin-x86-64.tar.gz"
        sha256 "956b7cdc4096d286dc69b0b6b36e93ddfb2be7aeb50d7b8b9121c50012ac0a5a"
      end
    end
  end

  head do
    url "https://github.com/cachewerk/relay.git", branch: "main"

    resource "ext-relay" do
      if Hardware::CPU.arm?
        # head: php8.2-darwin-arm64
        url "https://builds.r2.relay.so/dev/relay-dev-php8.2-darwin-arm64.tar.gz"
      else
        # head: php8.2-darwin-x86-64
        url "https://builds.r2.relay.so/dev/relay-dev-php8.2-darwin-x86-64.tar.gz"
      end
    end
  end

  def conf_dir
    Pathname(Utils.safe_popen_read(Formula["php"].opt_bin/"php-config", "--ini-dir").chomp)
  end

  def install
    php = (Formula["php"].opt_bin/"php").to_s
    extensions = Utils.safe_popen_read(php, "-m")

    ["json", "igbinary", "msgpack"].each do |name|
      unless /^#{name}/.match?(extensions)
        raise "Relay requires the `#{name}` extension. Install it using `\033[32mpecl install #{name}\033[0m`."
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
      (etc/"relay").install "relay.ini"

      # upsert absolute path to extension if `relay.ini` already existed
      inreplace etc/"relay/relay.ini", /extension\s*=.+$/, "extension = #{lib}/relay.so"

      # create ini soft link if necessary
      ln_s etc/"relay/relay.ini", conf_dir/"ext-relay.ini" unless (conf_dir/"ext-relay.ini").exist?
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
        `\033[32mbrew services restart php\033[0m`
    EOS
  end
end
