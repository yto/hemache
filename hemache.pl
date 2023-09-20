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
    add_to_log_file_list(\@log_file_list, $input_fn);
    read_log_file(\%dat, $log_file_list[0]);
    read_db_file_and_update_db_and_output(\%dat, $db_fn);
} elsif ($db_fn) { # clean DB
    read_db_file_and_update_db_and_output({}, $db_fn);
} else { # build DB
    while (<>) { # read log file name list
	chomp;
	add_to_log_file_list(\@log_file_list, $_) if -s $_;
    }
    foreach my $fni (sort {$a->{'ymdh'} <=> $b->{'ymdh'}} @log_file_list) {
	read_log_file_and_update_db(\%dat, $fni);
    }
    #warn "read and up done";
    foreach my $id (sort keys %dat) {
	if ($delete_on) {
	    delete_deleted($dat{$id}{list});
	    sort_and_dedup($dat{$id}{list});
	}
	print join("\t", $id, map {join(",", @$_)} @{$dat{$id}{list}})."\n";
    }
}

exit;

sub add_to_log_file_list {
    my ($l_r, $fn) = @_;
    die "bad file [$fn]" if not -f $fn;
    die "file name error [$fn]" if not $fn =~ m{\D(\d{10}|\d{8})[^/]+$};
    push @$l_r, {'ymdh' => $1, 'fn' => $fn};
}

sub read_log_file {
    my ($dat_r, $fni) = @_;
    my $fh = open_file($fni->{"fn"});
    while (<$fh>) {
	chomp;
	next if /^\s*$/ or /^\#/;
	my ($id, $cont) = split(/\t/, $_);
	$dat_r->{$id} = [$fni->{"ymdh"}, $cont];
	#warn "new> $." if $. % 10000 == 0;
    }
    close($fh);
}

sub read_db_file_and_update_db_and_output {
    my ($dat_r, $fn) = @_;
    my $fh = open_file($fn);
    my $ymdh = %$dat_r ? $dat_r->{(keys %$dat_r)[0]}[0] : "";
    my %seen;
    while (<$fh>) { # DBファイルを一行ずつ読み込んで処理
	chomp;
	next if /^\s*$/ or /^\#/;
	my ($id, @cols) = split(/\t/, $_);
	my @hist = map {/^(\d+),(.*)$/; [$1, $2]} @cols;
	sort_and_dedup(\@hist);
	if (%$dat_r) { # 追加データがあるときの処理
	    if (defined $dat_r->{$id}) { # 追加 or スルー
		add_one(\@hist, [$ymdh, $dat_r->{$id}[1]]);
	    } else { # 今回のログから消えてる場合の処理
		add_one(\@hist, [$ymdh, $deleted_label]);
	    }
	}
	if ($delete_on) {
	    delete_deleted(\@hist);
	    sort_and_dedup(\@hist);
	}
	print join("\t", $id, map {join(",", @$_)} @hist)."\n";
	#warn "db> $." if $. % 10000 == 0;
	$seen{$id} = 1;
    }
    close($fh);
    return if !%$dat_r;
    # 新規
    foreach my $id (grep {!$seen{$_}} keys %$dat_r) {
	print join("\t", $id, map {join(",", @$_)} ([$ymdh, $dat_r->{$id}[1]]))."\n";
    }
}

sub read_log_file_and_update_db {
    my ($dat_r, $fni) = @_;
    my $fh = open_file($fni->{"fn"});
    my %seen;
    while (<$fh>) {
	chomp;
	next if /^\s*$/ or /^\#/;
	my ($id, $cont) = split(/\t/, $_);
	@{$dat_r->{$id}{list}} = () if not defined $dat_r->{$id}{list};
	add_one($dat_r->{$id}{list}, [$fni->{"ymdh"}, $cont]);
	$seen{$id} = 1;
	#warn "up> $." if $. % 10000 == 0;
    }
    close($fh);
    #warn "read done";
    # ファイルから消えたIDの処理
    add_one($dat_r->{$_}{list}, [$fni->{"ymdh"}, $deleted_label]) for grep {!$seen{$_}} keys %$dat_r;
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
    if (not @$d_r) { # 一番最初は追加
	@$d_r = ([$ymdh, $cont]);
    } elsif ($cont ne $d_r->[0][1]) { # 前のと異なる場合
	if ($ymdh eq $d_r->[0][0]) { # 日付が同じ場合は上書き
	    $d_r->[0][1] = $cont;
	} else { # そうでない場合は普通に追加
	    unshift @$d_r, [$ymdh, $cont];
	}
    }
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
