#!/usr/bin/perl
# ls.pl - Prints colorized directory items like GNU ls does
#
# Copyright (C) 2010 Joachim "Joe" Stiegler <blablabla@trullowitsch.de>
# 
# This program is free software; you can redistribute it and/or modify it under the terms
# of the GNU General Public License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program;
# if not, see <http://www.gnu.org/licenses/>.
#
# --
# 
# Version: 1.0 - 2010-10-13
#
# TODO:
# Option t (sort by timestamp)
# Option d (stat directory)
# Standard output like ls -C ($cols exists...)
# If file is a link, show target (fileA -> fileB)

use warnings;
use strict;
use Cwd;
use Term::ANSIColor;
use Fcntl ':mode';
use POSIX qw(strftime);
use Getopt::Std;

if (!getopts ("ahilrsA")) {
	die "Usage: $0 [-ahilrsA]\n";
}

our ($opt_a, $opt_h, $opt_i, $opt_l, $opt_r, $opt_s, $opt_A);

my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks);

my @dirent;

my $columns = `tput cols`;

if (!defined($columns)) {
	my $columns = 80;
}

if (!@ARGV) {
	push @ARGV, getcwd;
}

my $argc = scalar @ARGV;

sub getsize {
	my $size = shift(@_);

	if ( ($size >= 1024) && ($size <= 1048576) ) {
		$size = sprintf("%.1f%s", $size / 1024, "K");
	}
	elsif ( ($size >= 1048576) && ($size <= 1073741824) ) {
		$size = sprintf("%.1f%s", $size / (1024 ** 2), "M");
	}
	elsif ( ($size >= 1073741824) && ($size <= 1099511627776) ) {
		$size = sprintf("%.1f%s", $size / (1024 ** 3), "G");
	}
	elsif ( ($size >= 1099511627776) && ($size <= 1125899906842624) ) {
		$size = sprintf("%.1f%s", $size / (1024 ** 4), "T");
	}

	return ($size);
}

sub readdirectory {
	my $dir = shift(@_);
	opendir(my $pwd, $dir) || die "$dir: $!\n";

	if (defined($opt_r)) {
		@dirent = sort {$b cmp $a} readdir($pwd);
	}
	else {
		@dirent = sort readdir($pwd);
	}

	closedir $pwd;
	return (@dirent);
}

sub readfile {
	@dirent = shift(@_);
	return (@dirent);
}

for (my $d=0; $d<=$argc-1;$d++) {
	if (-e $ARGV[$d]) {
		if (-d $ARGV[$d]) {
			print "\n$ARGV[$d]:\n" if ($argc > 1);
			@dirent = readdirectory($ARGV[$d]);
		}
		else {
			@dirent = readfile($ARGV[$d]);
		}
	}
	else {
		print "$ARGV[$d]: No such file or directory\n";
		next;
	}

	# Find the length of the longest item.
	my $current=0;
	my $longest=0;

	foreach my $j (@dirent) {
		foreach my $k (@dirent) {
			if (length($j) > length($k)) {
				$current = length($j);
			}
		}
		if ($longest < $current) {
			$longest = $current;
		}
	}
	
	# Number of columns for output like ls -C
	my $cols = int($columns / ($longest + 1));

	my $items = scalar @dirent;

	#FIXME:
	# If "ls.pl -l foodir/ foofile", then foofile can't be found, because our cwd is now foodir
	chdir $ARGV[$d];

	for (my $i=0; $i<=$items-1; $i++) {
		if ( ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = lstat($dirent[$i]) ) {

			my $time = strftime "%b %e %H:%M:%S %Y", localtime($mtime);

			my $user = getpwuid($uid);
			my $group = getgrgid($gid);

			if (defined($opt_h)) {
				$size = getsize($size);
			}

			if (defined($opt_A)) {
				if ($dirent[$i] =~ /^\.$/) {
					next;
				}
				elsif ($dirent[$i] =~ /^\.\.$/) {
					next;
				}
			}

			if ( (!defined($opt_a)) && (!defined($opt_A)) ) {
				if ($dirent[$i] =~ /^\./) {
					next;
				}
			}

			my $moderwx;

			if (-d $dirent[$i]) {
				$moderwx .= "d";
			}
			elsif (-l $dirent[$i]) {
				$moderwx .= "l";
			}
			elsif (-f $dirent[$i]) {
				$moderwx .= "-";
			}
			elsif (-b $dirent[$i]) {
				$moderwx .= "b";
			}
			elsif (-c $dirent[$i]) {
				$moderwx .= "c";
			}
			elsif (-p $dirent[$i]) {
				$moderwx .= "p";
			}
			elsif (-S $dirent[$i]) {
				$moderwx .= "S";
			}
			
			use Switch;

			my $nmode = sprintf ("%4o", S_IMODE($mode));
			my @modes = split (/ */, $nmode);
			foreach my $number (@modes) {
				switch ($number) {
					case 0 { $moderwx .= "---"; }
					case 7 { $moderwx .= "rwx"; }
					case 6 { $moderwx .= "rw-"; }
					case 5 { $moderwx .= "r-x"; }
					case 4 { $moderwx .= "r--"; }
				}
			}

			if ( (defined($opt_l)) && (defined($opt_i)) && (defined($opt_s)) ) {
				printf ("%10s %5s %10s %4s %10s %10s %10s %20s ", $ino,$blocks,$moderwx,$nlink,$user,$group,$size,$time);
			}
			elsif ( (defined($opt_l)) && (defined($opt_i)) && (!defined($opt_s)) ) {
				printf ("%10s %10s %4s %10s %10s %10s %20s ", $ino,$moderwx,$nlink,$user,$group,$size,$time);
			}
			elsif ( (defined($opt_l)) && (!defined($opt_i)) && (defined($opt_s)) ) {
				printf ("%5s %10s %4s %10s %10s %10s %20s ", $blocks,$moderwx,$nlink,$user,$group,$size,$time);
			}
			elsif ( (defined($opt_l)) && (!defined($opt_i)) && (!defined($opt_s)) ) {
				printf ("%10s %4s %10s %10s %10s %20s ", $moderwx,$nlink,$user,$group,$size,$time);
			}
			elsif ( (!defined($opt_l)) && (defined($opt_i)) && (defined($opt_s)) ) {
				printf ("%10s %5s ", $ino,$blocks);
			}
			elsif ( (!defined($opt_l)) && (defined($opt_i)) && (!defined($opt_s)) ) {
				printf ("%10s ", $ino);
			}
			elsif ( (!defined($opt_l)) && (!defined($opt_i)) && (defined($opt_s)) ) {
				printf ("%5s ", $blocks);
			}

			if (-d $dirent[$i]) {
				print color 'bold blue';
			}
			elsif (-l $dirent[$i]) {
				if (!stat($dirent[$i])) {
					print color 'bold red';
				}
				else {
					print color 'bold cyan';
				}
			}
			elsif (-x $dirent[$i]) {
				print color 'bold green';
			}

#			if (!defined($opt_l)) {
#				for (my $col=0; $col<=$cols; $col++) {
#					printf "%s ", $dirent[$i++];
#				}
#			}
#			else {
				print $dirent[$i];
#			}
			print color 'reset';
			print "\n";
		}
		else {
			print "can't stat file $dirent[$i]. this should never happens...";
		}
	}
}
