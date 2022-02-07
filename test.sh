#!/usr/bin/env zsh

diff \
    test/ok-output.txt \
    <(find test/dat/ -name '*.tsv' | ./hemache.pl)

diff \
    <(find test/{dat,new}/ -name '202201*.tsv' | ./hemache.pl) \
    <(./hemache.pl -d test/ok-output.txt -i test/new/20220106.tsv)

diff \
    test/ok-delete-output.txt \
    <(./hemache.pl -D -d test/db-delete.tsv -i test/new/20220201.tsv)
