# Homebrew tap for Relay

To install the Relay extension for PHP using Homebrew determine the PHP version using `php -v` and then install the matching extension:

```bash
brew install cachewerk/tap/relay      # PHP 8.5
brew install cachewerk/tap/relay@7.4  # PHP 7.4
```

The `igbinary` and `msgpack` PHP extensions are optional. They're only needed if you want to use Relay's igbinary or msgpack serializers, and Relay detects them at runtime — it loads and works fine without them. If you'd like to use those serializers, you can install the extensions using PECL:

```bash
pecl install msgpack
pecl install igbinary
```

After the installation is completed, be sure to restart your PHP-FPM and web server services:

```bash
sudo brew services restart php
sudo brew services restart nginx
```

## Links

- [Documentation](https://relay.so/docs)
- [Discussions](https://github.com/cachewerk/relay/discussions)
- [Bluesky](https://bsky.app/profile/relay.so)

## Uninstall

```php
brew uninstall relay
rm $(php-config --ini-dir)/ext-relay.ini

# brew uninstall relay@8.1
# rm $($(brew --prefix php@8.1)/bin/php-config --ini-dir)/ext-relay.ini

rm -rf /opt/homebrew/etc/relay
```

## Development

Check the formula syntax before committing.

```bash
brew style cachewerk/tap
```
