#!/usr/bin/env zsh

diff \
    test/ok-output.txt \
    <(find test/dat/ -name '*.tsv' | ./hemache.pl)

diff \
    <(find test/{dat,new}/ -name '*.tsv' | ./hemache.pl) \
    <(./hemache.pl -d test/ok-output.txt -i test/new/20220106.tsv)

