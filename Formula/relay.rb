class Relay < Formula
  desc "Next-generation caching layer for PHP"
  homepage "https://relaycache.com"

  depends_on "php"
  depends_on "jemalloc"
  depends_on "hiredis" => "1.0.0"
  depends_on "concurrencykit" => "0.7.0"
  depends_on "liblzf"
  depends_on "lz4"
  depends_on "zstd"

  bottle :unneeded

  php_ver = Utils.safe_popen_read("#{HOMEBREW_PREFIX}/bin/php-config", "--version").chomp.slice(0, 3)

  stable do
    url "https://github.com/cachewerk/relay.git", :tag => "v0.3.0",

    resource "ext-relay" do
      if Hardware::CPU.arm?
        case php_ver
          when "8.0"
            url "https://cachewerk.s3.amazonaws.com/relay/relay-v0.3.0-php8.0-darwin-arm64.tar.gz"
          when "7.4"
            url "https://cachewerk.s3.amazonaws.com/relay/relay-v0.3.0-php7.4-darwin-arm64.tar.gz"
        end
      else
        case php_ver
          when "8.0"
            url "https://cachewerk.s3.amazonaws.com/relay/relay-v0.3.0-php8.0-darwin-x86-64.tar.gz"
          when "7.4"
            url "https://cachewerk.s3.amazonaws.com/relay/relay-v0.3.0-php7.4-darwin-x86-64.tar.gz"
        end
      end
    end
  end

  head do
    url "https://github.com/cachewerk/relay.git", :branch => "main"

    resource "ext-relay" do
      if Hardware::CPU.arm?
        case php_ver
          when "8.0"
            url "https://cachewerk.s3.amazonaws.com/relay/relay-dev-php8.0-darwin-arm64.tar.gz"
          when "7.4"
            url "https://cachewerk.s3.amazonaws.com/relay/relay-dev-php7.4-darwin-arm64.tar.gz"
        end
      else
        case php_ver
          when "8.0"
            url "https://cachewerk.s3.amazonaws.com/relay/relay-dev-php8.0-darwin-x86-64.tar.gz"
          when "7.4"
            url "https://cachewerk.s3.amazonaws.com/relay/relay-dev-php7.4-darwin-x86-64.tar.gz"
        end
      end
    end
  end

  def conf_dir
    Pathname(Utils.safe_popen_read("#{HOMEBREW_PREFIX}/bin/php-config", "--ini-dir").chomp)
  end

  def install
    extensions = Utils.safe_popen_read("#{HOMEBREW_PREFIX}/bin/php", "-m")

    required = ["json", "igbinary", "msgpack"]

    required.each { |extension|
      unless extensions.match(/^#{extension}/)
        raise "Relay requires the `#{extension}` extension. Install it using `\033[32mpecl install #{extension}\033[0m`."
      end
    }

    resource("ext-relay").stage do
      lib.install "relay.so"
    end

    # set absolute path to extension
    inreplace "relay.ini", "extension = relay.so", "extension = #{lib}/relay.so"

    # install ini file to `etc/` (won’t overwrite)
    (etc/"relay").install "relay.ini"

    # upsert absolute path to extension if `relay.ini` already existed
    inreplace etc/"relay/relay.ini", /extension =.+$/, "extension = #{lib}/relay.so"

    # create ini soft link if necessary
    ln_s etc/"relay/relay.ini", conf_dir/"ext-relay.ini" unless (conf_dir/"ext-relay.ini").exist?
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
