#!/usr/bin/perl -w
use strict;
use DBIx::Simple;
use File::Path;
my $DEBUG = 0; 

my $dump_dir = '/var/lib/postgresql/db_dump/10';
my $bl_file = defined $ARGV[0]? $ARGV[0] : "/var/lib/postgresql/.db_dumb.blacklist";
my $pgdumpcom = "pg_dump -Fd -o -Z7 -w -U postgres";

# Read file with blacklist matches
open(my $fh, '<', $bl_file) or die "Cannot open $bl_file for reading";

# read each line as an expression and add to one big expressiong
my $rawregex = join( '|', map { chomp; $_ }  <$fh>  );

close($fh);

# compile regex to save cpu time
my $blacklist = qr/(?:$rawregex)/;
print "Using regex: $blacklist\n" if($DEBUG);

## Connect and retrieve list of databases
my $dbi = DBIx::Simple->connect('dbi:Pg:dbname=postgres', 'postgres') or die DBIx::Simple->error;
my @database_list = $dbi->query('SELECT datname FROM pg_database WHERE datistemplate = false;')->flat;

my @backupdbs;
my @blocked;

## Filter out blacklisted names
for my $dbname (@database_list) {
	if($dbname =~ $blacklist) {
		push(@blocked, $dbname) if($DEBUG);
		next;
	}
	push(@backupdbs, $dbname);
}

if($DEBUG) {
	print "The following databases will NOT be backed up:\n";
	print " * $_\n" for(@blocked);
}

## Make backups of non-blacklisted databases
for my $dbname (@backupdbs) {
	my $dumplocation = "$dump_dir/$dbname.dump";
	if (-e $dumplocation) {
		if(-d $dumplocation) {
			print "Removing old backup: $dumplocation\n" if($DEBUG);
			rmtree($dumplocation);
		} else {
			die "$dumplocation exists, but not a directory, please double check and remove manually"
		}
	}

	print "Dumping $dbname\n";
	system("$pgdumpcom -d \"$dbname\" -f \"$dumplocation\"\n") and print "Error ($dbname): $!";
}

