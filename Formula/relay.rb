require "securerandom"

class Relay < Formula
  desc "Next-generation caching layer for PHP"
  homepage "https://relay.so"

  stable do
    url "https://github.com/cachewerk/relay.git", tag: "v0.40.0"

    resource "ext-relay" do
      # stable: php8.5-darwin-arm64
      url "https://builds.r2.relay.so/v0.40.0/relay-v0.40.0-php8.5-darwin-arm64.tar.gz"
      sha256 "d331f5443d94ab9b86e139d4b18cec62051d52c86c28d5349336dd346efbb1df"
    end
  end

  head do
    url "https://github.com/cachewerk/relay.git", branch: "main"

    resource "ext-relay" do
      # head: php8.5-darwin-arm64
      url "https://builds.r2.relay.so/dev/relay-dev-php8.5-darwin-arm64.tar.gz"
    end
  end

  depends_on "concurrencykit"
  depends_on "hiredis"
  depends_on "php"

  def conf_dir
    Pathname(Utils.safe_popen_read(formula_opt_bin("php")/"php-config", "--ini-dir").chomp)
  end

  def install
    php = (formula_opt_bin("php")/"php").to_s
    extensions = Utils.safe_popen_read(php, "-m")

    ["json"].each do |name|
      unless /^#{name}/.match?(extensions)
        raise "Relay requires the `#{name}` extension. Install it using `\033[32mpecl install #{name}\033[0m`."
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
      (etc/"relay").install "relay.ini"

      # upsert absolute path to extension if `relay.ini` already existed
      inreplace etc/"relay/relay.ini", /extension\s*=.+$/, "extension = #{lib}/relay.so"

      # (re)create ini soft link, replacing any unexpected leftover
      conf_dir.mkdir unless conf_dir.exist?
      target = etc/"relay/relay.ini"
      link = conf_dir/"ext-relay.ini"
      if link.symlink? || link.exist?
        opoo "Replacing #{link}" if !link.symlink? || link.readlink != target
        link.unlink
      end
      ln_s target, link
    end
  end

  def caveats
    <<~EOS
      The Relay extension for PHP was installed at:
        #{lib}/relay.so

      The configuration file was symlinked to:
        #{conf_dir}/ext-relay.ini

      The `igbinary` (recommended) and `msgpack` extensions are optional.
      Install them using `\033[32mpecl install igbinary\033[0m`.

      Run `\033[32mphp --ri relay\033[0m` to ensure Relay is working.

      Finally, be sure to restart your PHP-FPM service:
        `\033[32mbrew services restart php\033[0m`
    EOS
  end
end
