# Relay Homebrew tap

Install the Relay extension for PHP using Homebrew.

First, add the tap:

```bash
brew tap cachewerk/tap
```

Next, determine your PHP version using `php -v` and install the matching extension:

```bash
brew install relay      # PHP 8.0
brew install relay@7.4  # PHP 7.4
```

When prompted to install any required extensions, do so using PECL:

```bash
pecl install msgpack igbinary
```

## Links

- [Documentation](https://relaycache.com/docs)
- [Twitter](https://twitter.com/RelayCache)
- [Discussions](https://github.com/cachewerk/relay/discussions)

## Development

Check the formula syntax before committing.

```bash
brew style cachewerk/tap
```
