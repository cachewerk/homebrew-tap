require "securerandom"

class RelayAT83 < Formula
  desc "Next-generation caching layer for PHP"
  homepage "https://relay.so"

  stable do
    url "https://github.com/cachewerk/relay.git", tag: "v0.40.0"

    resource "ext-relay" do
      # stable: php8.3-darwin-arm64
      url "https://builds.r2.relay.so/v0.40.0/relay-v0.40.0-php8.3-darwin-arm64.tar.gz"
      sha256 "390004aed36d088a4d9b3d986df84b27db9e1fb9a165aea3d58b5cb87d3439bf"
    end
  end

  head do
    url "https://github.com/cachewerk/relay.git", branch: "main"

    resource "ext-relay" do
      # head: php8.3-darwin-arm64
      url "https://builds.r2.relay.so/dev/relay-dev-php8.3-darwin-arm64.tar.gz"
    end
  end

  keg_only :versioned_formula

  depends_on "concurrencykit"
  depends_on "hiredis"
  depends_on "php@8.3"

  def conf_dir
    Pathname(Utils.safe_popen_read(formula_opt_bin("php@8.3")/"php-config", "--ini-dir").chomp)
  end

  def install
    php = (formula_opt_bin("php@8.3")/"php").to_s
    pecl = (formula_opt_bin("php@8.3")/"pecl").to_s

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

      {
        /libhiredis\./     => formula_opt_lib("hiredis")/"libhiredis.dylib",
        /libhiredis_ssl\./ => formula_opt_lib("hiredis")/"libhiredis_ssl.dylib",
        /libssl/           => formula_opt_lib("openssl")/"libssl.dylib",
        /libcrypto/        => formula_opt_lib("openssl")/"libcrypto.dylib",
        /libck/            => formula_opt_lib("ck")/"libck.dylib",
      }.each do |pattern, new_name|
        old_name = dylibs.grep(pattern).first
        MachO::Tools.change_install_name("relay.so", old_name, new_name.to_s) if old_name
      end

      # Apply ad-hoc code signature
      MachO.codesign!("relay.so")

      # move extension file
      lib.install "relay.so"

      # set absolute path to extension
      inreplace "relay.ini", "extension = relay.so", "extension = #{lib}/relay.so"

      # install ini file to `etc/` (won't overwrite)
      (etc/"relay").install "relay.ini" => "relay@8.3.ini"

      # upsert absolute path to extension if `relay.ini` already existed
      inreplace etc/"relay/relay@8.3.ini", /extension\s*=.+$/, "extension = #{lib}/relay.so"

      # create ini soft link if necessary
      conf_dir.mkdir unless conf_dir.exist?
      ln_s etc/"relay/relay@8.3.ini", conf_dir/"ext-relay.ini" unless (conf_dir/"ext-relay.ini").exist?
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
        `\033[32mbrew services restart php@8.3\033[0m`
    EOS
  end
end
