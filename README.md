# Homebrew tap for Relay

To install the Relay extension for PHP using Homebrew, first add the tap:

```bash
brew tap cachewerk/tap
```

Next, determine your PHP version using `php -v` and install the matching extension:

```bash
brew install relay      # PHP 8.3
brew install relay@8.2  # PHP 8.2
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
