# Homebrew tap for Relay

To install the Relay extension for PHP using Homebrew, first add the tap:

```bash
brew tap cachewerk/tap
```

Next, determine your PHP version using `php -v` and install the matching extension:

```bash
brew install relay      # PHP 8.1
brew install relay@8.0  # PHP 8.0
brew install relay@7.4  # PHP 7.4
```

The installation might abort and you'll be prompted to install some PHP extensions that Relay requires. You can install them using PECL:

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
- [Twitter](https://twitter.com/RelayPHP)
- [Discussions](https://github.com/cachewerk/relay/discussions)

## Uninstall

```php
brew uninstall relay
# brew uninstall relay@7.4

rm -rf /opt/homebrew/etc/relay
rm $(php-config --ini-dir)/ext-relay.ini
```

## Development

Check the formula syntax before committing.

```bash
brew style cachewerk/tap
```
