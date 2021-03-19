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

  phpver = Utils.safe_popen_read("#{HOMEBREW_PREFIX}/bin/php-config", "--version").chomp.slice(0, 3)

  stable do
    url "https://cachewerk.s3.amazonaws.com/relay/relay-v0.3.0-php8.0-darwin-arm64.tar.gz"

    resource "ext-relay" do
      if Hardware::CPU.arm?
        case phpver
          when "8.0"
            url "https://cachewerk.s3.amazonaws.com/relay/relay-v0.3.0-php8.0-darwin-arm64.tar.gz"
          when "7.4"
            url "https://cachewerk.s3.amazonaws.com/relay/relay-v0.3.0-php7.4-darwin-arm64.tar.gz"
        end
      else
        case phpver
          when "8.0"
            url "https://cachewerk.s3.amazonaws.com/relay/relay-v0.3.0-php8.0-darwin-x86-64.tar.gz"
          when "7.4"
            url "https://cachewerk.s3.amazonaws.com/relay/relay-v0.3.0-php7.4-darwin-x86-64.tar.gz"
        end
      end
    end
  end

  head do
    url "https://cachewerk.s3.amazonaws.com/relay/relay-dev-php8.0-darwin-arm64.tar.gz"

    resource "ext-relay" do
      if Hardware::CPU.arm?
        case phpver
          when "8.0"
            url "https://cachewerk.s3.amazonaws.com/relay/relay-dev-php8.0-darwin-arm64.tar.gz"
          when "7.4"
            url "https://cachewerk.s3.amazonaws.com/relay/relay-dev-php7.4-darwin-arm64.tar.gz"
        end
      else
        case phpver
          when "8.0"
            url "https://cachewerk.s3.amazonaws.com/relay/relay-dev-php8.0-darwin-x86-64.tar.gz"
          when "7.4"
            url "https://cachewerk.s3.amazonaws.com/relay/relay-dev-php7.4-darwin-x86-64.tar.gz"
        end
      end
    end
  end
  def install
    lib.install resource("ext-relay")

    inreplace "relay.ini", "extension = relay.so", "extension = #{lib}/relay.so"

    # creates `relay.ini.default` if `relay.ini` exists
    (etc/"relay").install "relay.ini"

    # set absolute path to extension
    inreplace etc/"relay/relay.ini", /extension =.+$/, "extension = #{lib}/relay.so"

    # determine `PHP_CONFIG_FILE_SCAN_DIR`
    conf_dir = Pathname(Utils.safe_popen_read("#{HOMEBREW_PREFIX}/bin/php-config", "--ini-dir").chomp)

    # create ini soft link if necessary
    ln_s etc/"relay/relay.ini", conf_dir/"ext-relay.ini" unless (conf_dir/"ext-relay.ini").exist?
  end

  def caveats
    <<~EOS
      etc/relay/relay.ini was added and symlinked to 
      RUN TEST IN `install` TO ENSURE IT'S WORKING

      php --ri relay

      `Extension 'relay' not present.`
    EOS
  end
end
