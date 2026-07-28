require "securerandom"

class RelayAT82 < Formula
  desc "Next-generation caching layer for PHP"
  homepage "https://relay.so"

  stable do
    url "https://github.com/cachewerk/relay.git", tag: "v0.40.0"

    resource "ext-relay" do
      if Hardware::CPU.arm?
        # stable: php8.2-darwin-arm64
        url "https://builds.r2.relay.so/v0.40.0/relay-v0.40.0-php8.2-darwin-arm64.tar.gz"
        sha256 "21ea0e6159e9d2c583f96c3f77c0f00de9aa5efffa9de116137836b711c4b848"
      else
        # stable: php8.2-darwin-x86-64
        url "https://builds.r2.relay.so/v0.7.0/relay-v0.7.0-php8.2-darwin-x86-64.tar.gz"
        sha256 "1f7116164fd9984f9f494f7c9cb1f2ab5a75bed53f4d8a76f0eccd2e8c7a9186"
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

  keg_only :versioned_formula

  depends_on "concurrencykit"
  depends_on "hiredis"
  depends_on "lz4"
  depends_on "php@8.2"
  depends_on "zstd"

  def conf_dir
    Pathname(Utils.safe_popen_read(formula_opt_bin("php@8.2")/"php-config", "--ini-dir").chomp)
  end

  def install
    php = (formula_opt_bin("php@8.2")/"php").to_s
    pecl = (formula_opt_bin("php@8.2")/"pecl").to_s

    extensions = Utils.safe_popen_read(php, "-m")

    ["json"].each do |name|
      unless /^#{name}/.match?(extensions)
        raise "Relay requires the `#{name}` extension. Install it using `\033[32m#{pecl} install #{name}\033[0m`."
      end
    end

    resource("ext-relay").stage do
      chmod 0644, "relay.so"

      # inject UUID into binary
      `LC_ALL=C /usr/bin/sed -i '' s/00000000-0000-0000-0000-000000000000/#{SecureRandom.uuid}/ relay.so`

      # relink dependencies
      dylibs = MachO::Tools.dylibs("relay.so")

      MachO::Tools.change_install_name("relay.so", dylibs.grep(/libhiredis\./).first, (formula_opt_lib("hiredis")/"libhiredis.dylib").to_s)
      MachO::Tools.change_install_name("relay.so", dylibs.grep(/libhiredis_ssl\./).first, (formula_opt_lib("hiredis")/"libhiredis_ssl.dylib").to_s)

      MachO::Tools.change_install_name("relay.so", dylibs.grep(/libssl/).first, (formula_opt_lib("openssl")/"libssl.dylib").to_s)
      MachO::Tools.change_install_name("relay.so", dylibs.grep(/libcrypto/).first, (formula_opt_lib("openssl")/"libcrypto.dylib").to_s)

      MachO::Tools.change_install_name("relay.so", dylibs.grep(/libzstd/).first, (formula_opt_lib("zstd")/"libzstd.dylib").to_s)
      MachO::Tools.change_install_name("relay.so", dylibs.grep(/liblz4/).first, (formula_opt_lib("lz4")/"liblz4.dylib").to_s)

      if Hardware::CPU.intel?
        MachO::Tools.change_install_name("relay.so", dylibs.grep(/libck/).first, (formula_opt_lib("ck")/"libck.dylib").to_s)
      end

      # Apply ad-hoc code signature
      MachO.codesign!("relay.so") if Hardware::CPU.arm?

      # move extension file
      lib.install "relay.so"

      # set absolute path to extension
      inreplace "relay.ini", "extension = relay.so", "extension = #{lib}/relay.so"

      # install ini file to `etc/` (won't overwrite)
      (etc/"relay").install "relay.ini" => "relay@8.2.ini"

      # upsert absolute path to extension if `relay.ini` already existed
      inreplace etc/"relay/relay@8.2.ini", /extension\s*=.+$/, "extension = #{lib}/relay.so"

      # create ini soft link if necessary
      conf_dir.mkdir unless conf_dir.exist?
      ln_s etc/"relay/relay@8.2.ini", conf_dir/"ext-relay.ini" unless (conf_dir/"ext-relay.ini").exist?
    end
  end

  def caveats
    <<~EOS
      The Relay extension for PHP was installed at:
        #{lib}/relay.so

      The configuration file was symlinked to:
        #{conf_dir}/ext-relay.ini

      The `igbinary` (recommended) and `msgpack` extensions are optional.
      Install them using `\033[32m#{pecl} install igbinary\033[0m`.

      Run `\033[32mphp --ri relay\033[0m` to ensure Relay is working.

      Finally, be sure to restart your PHP-FPM service:
        `\033[32mbrew services restart php@8.2\033[0m`
    EOS
  end
end
