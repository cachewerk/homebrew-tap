require "securerandom"

class RelayAT74 < Formula
  desc "Next-generation caching layer for PHP"
  homepage "https://relaycache.com"

  stable do
    url "https://github.com/cachewerk/relay.git", tag: "v0.1.0"

    resource "ext-relay" do
      if Hardware::CPU.arm?
        # stable: php7.4-darwin-arm64
        url "https://cachewerk.s3.amazonaws.com/relay/v0.1.0/relay-v0.1.0-php7.4-darwin-arm64.tar.gz"
        sha256 "e54326a195d86659c861ca72a208b909aa2ff268afa0f75fc19f9814ea6f59bc"
      else
        # stable: php7.4-darwin-x86-64
        url "https://cachewerk.s3.amazonaws.com/relay/v0.1.0/relay-v0.1.0-php7.4-darwin-x86-64.tar.gz"
        sha256 "03b1e39b2535fe78a601d13593137dd17499dcf1cef5d823fa4856b344cf390a"
      end
    end
  end

  head do
    url "https://github.com/cachewerk/relay.git", branch: "main"

    resource "ext-relay" do
      if Hardware::CPU.arm?
        # head: php7.4-darwin-arm64
        url "https://cachewerk.s3.amazonaws.com/relay/develop/relay-dev-php7.4-darwin-arm64.tar.gz"
      else
        # head: php7.4-darwin-x86-64
        url "https://cachewerk.s3.amazonaws.com/relay/develop/relay-dev-php7.4-darwin-x86-64.tar.gz"
      end
    end
  end

  bottle :unneeded

  # depends_on "concurrencykit" # v0.7.1+
  # depends_on "hiredis" # v1.0.1+
  depends_on "libev"
  depends_on "lz4"
  depends_on "openssl"
  depends_on "php@7.4"
  depends_on "zstd"

  def conf_dir
    Pathname(Utils.safe_popen_read(Formula["php@7.4"].opt_bin/"php-config", "--ini-dir").chomp)
  end

  def install
    php = (Formula["php@7.4"].opt_bin/"php").to_s
    extensions = Utils.safe_popen_read(php, "-m")

    ["json", "igbinary", "msgpack"].each do |name|
      unless /^#{name}/.match?(extensions)
        raise "Relay requires the `#{name}` extension. Install it using `\033[32mpecl install #{name}\033[0m`."
      end
    end

    resource("ext-relay").stage do
      mv "relay-pkg.so", "relay.so"
      chmod 0644, "relay.so"

      # inject UUID
      `LC_ALL=C /usr/bin/sed -i '' s/31415926-5358-9793-2384-626433832795/#{SecureRandom.uuid}/ relay.so`

      # relink dependencies
      dylibs = MachO::Tools.dylibs("relay.so")

      MachO::Tools.change_install_name("relay.so",
        dylibs.grep(/libev/).first,
        (Formula["libev"].opt_lib/"libev.dylib").to_s)

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

      Run `\033[32mphp --ri relay\033[0m` to ensure it’s working.
    EOS
  end
end
