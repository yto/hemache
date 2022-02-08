#!/usr/bin/env perl
# -*- coding: utf-8 -*-
use strict;
use warnings;
use utf8;
use open ":utf8";
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
$| = 1;

my $db_fn = ""; # DB file name (for update mode)
my $input_fn = ""; # latest log file name (for update mode)
my $delete_on; # delete deleted nodes
my $deleted_label = "[DELETED]";
GetOptions(
    'db|d=s' => \$db_fn,
    'input|i=s' => \$input_fn,
    'delete|D' => \$delete_on,
    'label|l=s' => \$deleted_label,
    );

my %dat;
my @log_file_list;
if ($input_fn and $db_fn) { # update DB
    read_db_file(\%dat, $db_fn);
    add_to_log_file_list(\@log_file_list, $input_fn);
} else { # build DB
    while (<>) { # read log file name list
	chomp;
	add_to_log_file_list(\@log_file_list, $_);
    }
}

foreach my $fni (sort {$a->{'ymdh'} <=> $b->{'ymdh'}} @log_file_list) {
    read_log_file_and_update_db(\%dat, $fni);
}

foreach my $id (sort keys %dat) {
    my $l_r = $delete_on ? delete_deleted($dat{$id}{list}) : $dat{$id}{list};
    print join("\t", $id, map {join(",", @$_)} @$l_r)."\n";
}

exit;

sub add_to_log_file_list {
    my ($l_r, $fn) = @_;
    die "bad file [$fn]" if not -f $fn;
    die "file name error [$fn]" if not $fn =~ m{/(\d{10}|\d{8})[^/]+$};
    push @$l_r, {'ymdh' => $1, 'fn' => $fn};
}

sub read_db_file {
    my ($dat_r, $fn) = @_;
    my $fh = open_file($fn);
    while (<$fh>) {
	chomp;
	next if /^\s*$/ or /^\#/;
	my ($id, @cols) = split(/\t/, $_);
	$dat_r->{$id}{list} = [map {/^(\d+),(.*)$/; [$1, $2]} @cols];
    }
    close($fh);
}

sub read_log_file_and_update_db {
    my ($dat_r, $fni) = @_;
    my $fh = open_file($fni->{"fn"});
    my %seen;
    while (<$fh>) {
	chomp;
	next if /^\s*$/ or /^\#/;
	my ($id, $cont) = split(/\t/, $_);
	add_one(\%{$dat_r->{$id}}, [$fni->{"ymdh"}, $cont]);
	$seen{$id} = 1;
    }
    close($fh);
    # ファイルから消えたIDの処理
    add_one($dat_r->{$_}, [$fni->{"ymdh"}, $deleted_label]) for grep {!$seen{$_}} keys %$dat_r;
}

sub open_file {
    my ($fn) = @_;
    my $fh;
    if ($fn =~ /\.gz$/) {
	open($fh, "zcat $fn |") or die "can't open [$fn]";
    } else {
	open($fh, "<", $fn) or die "can't open [$fn]";
    }
    return $fh;
}

sub add_one {
    my ($d_r, $r) = @_;
    my ($ymdh, $cont) = @$r;
    if (not defined $d_r->{list}) { # 一番最初は追加
	@{$d_r->{list}} = ([$ymdh, $cont]);
    } elsif ($cont ne $d_r->{list}[0][1]) { # 前のと異なる場合は追加
	unshift @{$d_r->{list}}, [$ymdh, $cont];
    }
}

# 途中にある DELETED を消す
sub delete_deleted {
    my ($l_r) = @_;
    return $l_r if not grep {$_->[1] =~ /\Q$deleted_label\E/} @$l_r[1..$#$l_r];
    my @new_list;
    for (my $i = $#$l_r; 0 <= $i; $i--) {
	if ($i != 0 and $l_r->[$i][1] =~ /\Q$deleted_label\E/) {
	    $i-- if $l_r->[$i-1][1] eq $l_r->[$i+1][1];
	    next;
	}
	unshift @new_list, $l_r->[$i];
    }
    return \@new_list;
}
