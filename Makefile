# hemache
#   make install                  # -> /usr/local/bin
#   make install PREFIX=$HOME     # -> $HOME/bin

PREFIX ?= /usr/local
BINDIR = $(DESTDIR)$(PREFIX)/bin
SCRIPTS = hemache.pl hm-sort-dedup.pl

all:

install:
	install -d $(BINDIR)
	install -m 755 $(SCRIPTS) $(BINDIR)

uninstall:
	cd $(BINDIR) && rm -f $(SCRIPTS)

.PHONY: all install uninstall
