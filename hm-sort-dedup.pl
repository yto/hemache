#!/usr/bin/env perl
# -*- coding: utf-8 -*-
use strict;
use warnings;
use List::Util qw(reduce);
use utf8;
use open ":utf8";
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
$| = 1;

my $delete_on; # delete deleted nodes
my $deleted_label = "[DELETED]";
GetOptions(
    'delete|D' => \$delete_on,
    'label|l=s' => \$deleted_label,
    );

while (<>) {
    chomp;
    next if /^\s*$/ or /^\#/;
    my ($id, @cols) = split(/\t/, $_);
    my @hist = map {/^(\d+),(.*)$/; [$1, $2]} @cols;
    delete_deleted(\@hist) if $delete_on;
    sort_and_dedup(\@hist);
    print join("\t", $id, map {join(",", @$_)} @hist)."\n";
}


sub sort_and_dedup {
    my ($l_r) = @_;
    my %seen;
    my @list = grep {!$seen{$_->[0]}++} sort {$b->[0] cmp $a->[0]} @$l_r;
    @$l_r = @{(reduce {!$a ? [$b] : do {pop @$a if $a->[-1][1] eq $b->[1]; [@$a, $b]}} undef, @list)};
    return;
}

# 途中にある DELETED を消す
sub delete_deleted {
    my ($l_r) = @_;
    return if @$l_r <= 2;
    my @new_list = ($l_r->[0], grep {$_->[1] !~ /\Q$deleted_label\E/} @$l_r[1..$#$l_r]);
    return if @$l_r == @new_list;
    @$l_r = @new_list;
}



