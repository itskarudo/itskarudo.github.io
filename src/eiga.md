# download movies, shows and anime from the command line.

over the past few days I've been wanting to learn bash, so I started working on [eiga](https://github.com/itskarudo/eiga), a tool to download torrents from the command line.

_eiga_ allows you to download movies from [YTS](https://yts.mx), TV shows from [1337x](https://1337x.to), and anime from [nyaa.si](https://nyaa.si), it uses `curl` to request the data, [`jq`](https://github.com/stedolan/jq), `grep` and `sed` to parse the responses, and [`fzf`](https://github.com/junegunn/fzf) to display the search results in a user-friendly manner.

## install

make sure you have `curl`, `jq` and `fzf` installed.

```
$ git clone https://github.com/itskarudo/eiga && cd eiga
$ sudo cp ./eiga /usr/local/bin/
```

## usage

```
$ eiga
usage: eiga [options...]

Options:
    -m, --movies              Search in movie sources (yts.mx)
    -s, --shows               Search in TV shows sources (1337x)
    -a, --anime               Search in anime sources (nyaa.si)
    -p, --pages               Specify number of pages to fetch.
    -h, --help                Show this text and exit.
```

### example usage
#### fetch 2 pages off nyaa.si results
```
$ eiga --anime --pages 2
> fullmetal alchemist: brotherhood
```
#### search for both movies and TV shows
```
$ eiga -m -s
> breaking bad
```
