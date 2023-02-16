require "securerandom"

class RelayAT81 < Formula
  desc "Next-generation caching layer for PHP"
  homepage "https://relay.so"

  # depends_on "concurrencykit" # v0.7.1+
  depends_on "hiredis"
  depends_on "lz4"
  depends_on "openssl"
  depends_on "php@8.1"
  depends_on "zstd"

  stable do
    url "https://github.com/cachewerk/relay.git", tag: "v0.6.0"

    resource "ext-relay" do
      if Hardware::CPU.arm?
        # stable: php8.1-darwin-arm64
        url "https://github.com/cachewerk/relay/releases/download/v0.6.0/relay-v0.6.0-php8.1-darwin-arm64.tar.gz"
        sha256 "37c7da50fd207b4f76c304607697687116379f52b6237d07ecb906cb6c9253d1"
      else
        # stable: php8.1-darwin-x86-64
        url "https://github.com/cachewerk/relay/releases/download/v0.6.0/relay-v0.6.0-php8.1-darwin-x86-64.tar.gz"
        sha256 "53e1530514d0ada466152a9bc4faa0af5b3b4b2a04d010e98d6a940b0fef28c9"
      end
    end
  end

  head do
    url "https://github.com/cachewerk/relay.git", branch: "main"

    resource "ext-relay" do
      if Hardware::CPU.arm?
        # head: php8.1-darwin-arm64
        url "https://builds.r2.relay.so/dev/relay-dev-php8.1-darwin-arm64.tar.gz"
      else
        # head: php8.1-darwin-x86-64
        url "https://builds.r2.relay.so/dev/relay-dev-php8.1-darwin-x86-64.tar.gz"
      end
    end
  end

  def conf_dir
    Pathname(Utils.safe_popen_read(Formula["php@8.1"].opt_bin/"php-config", "--ini-dir").chomp)
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
