# https://docs.brew.sh/Formula-Cookbook
# https://github.com/blackfireio/homebrew-blackfire/blob/master/Abstract/abstract-blackfire-php-extension.rb
# 
# TODOs
#  - handle igbinary dependency
#  - handle PHP API versions

class Relay < Formula
  desc "Next-generation caching layer for PHP"
  homepage "https://relaycache.com"
  # license "BSD-2-Clause"
  url "https://cachewerk.s3.amazonaws.com/mac/20200930-v0.3.0.tar.gz"
  sha256 "127e74fd1342945480123ea1de82c7b5d16bd0c59cc96e468aa4aafa10f33a07"
  head "https://cachewerk.s3.amazonaws.com/mac/20200930-develop.tar.gz"

  depends_on "php"
  depends_on "jemalloc"
  depends_on "hiredis" => "1.0.0"
  depends_on "concurrencykit" => "0.7.0"
  depends_on "liblzf"
  depends_on "lz4"
  depends_on "zstd"

  bottle :unneeded

  def install
    lib.install "relay.so"

    inreplace "relay.ini", "extension = relay.so", "extension = #{lib}/relay.so"

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
