#!/usr/bin/perl
use strict;
use warnings;
use File::Find;
use File::Spec;
use FileHandle;
use IPC::Open2;
use Cwd;
use Getopt::Long;
use Pod::Usage;
our $VERSION = '1.0';

our $_PROGNAME = "dm.pl";

my $ADMINARCHIVENAME = "control.tar.gz";
my $DATAARCHIVENAME = "data.tar";
my $ARCHIVEVERSION = "2.0";

our $compression = "gzip";
Getopt::Long::Configure("bundling", "auto_version");
GetOptions('compression|Z=s' => \$compression,
	'build|b' => sub { },
	'help|?' => sub { pod2usage(1); },
	'man' => sub { pod2usage(-exitstatus => 0, -verbose => 2); })
	or pod2usage(2);

pod2usage(1) if(@ARGV < 2);

my $pwd = Cwd::cwd();
my $indir = File::Spec->rel2abs($ARGV[0]);
my $outfile = $ARGV[1];

my $tar = get_tar_version(); # aref: [name, ver]

die "ERROR: '$indir' is not a directory or does not exist.\n" unless -d $indir;

my $controldir = File::Spec->catpath("", $indir, "DEBIAN");

die "ERROR: control directory '$controldir' is not a directory or does not exist.\n" unless -d $controldir;
my $mode = (lstat($controldir))[2];
die sprintf("ERROR: control directory has bad permissions %03lo (must be >=0755 and <=0775)\n", $mode & 07777) if(($mode & 07757) != 0755);

my $controlfile = File::Spec->catfile("", $controldir, "control");
die "ERROR: control file '$controlfile' is not a plain file\n" unless -f $controlfile;
my %control_data = read_control_file($controlfile);

die "ERROR: package name has characters that aren't lowercase alphanums or '-+.'.\n" if($control_data{"package"} =~ m/[^a-z0-9+-.]/);
die "ERROR: package version ".$control_data{"version"}." doesn't contain any digits.\n" if($control_data{"version"} !~ m/[0-9]/);

foreach my $m ("preinst", "postinst", "prerm", "postrm", "extrainst_") {
	$_ = File::Spec->catfile("", $controldir, $m);
	next unless -e $_;
	die "ERROR: maintainer script '$m' is not a plain file or symlink\n" unless(-f $_ || -l $_);
	$mode = (lstat)[2];
	die sprintf("ERROR: maintainer script '$m' has bad permissions %03lo (must be >=0555 and <=0775)\n", $mode & 07777) if(($mode & 07557) != 0555)
}

open(my $ar, '>', $outfile) or die $!;

my ($tarin, $tarout);

chdir $controldir or die $!;
my ($controldata, $controlsize);
open($tarout, '-|', $tar->[0]." -c -f - . | gzip -c -9") or die "ERROR: failed to use tar properly (administrative archive): $!\n"; {
	my $o = 0;
	while(!eof $tarout) {
		$o += read $tarout, $controldata, 1024, $o;
	}
	$controlsize = $o;
} close $tarout;

print "$_PROGNAME: building package `".$control_data{"package"}.":".$control_data{"architecture"}."' in `$outfile'\n";

print $ar "!<arch>\n";
print_ar_record($ar, "debian-binary", time, 0, 0, 0100644, 4);
print_ar_file($ar, "$ARCHIVEVERSION\n", 4);
print_ar_record($ar, $ADMINARCHIVENAME, time, 0, 0, 0100644, $controlsize);
print_ar_file($ar, $controldata, $controlsize);

chdir $indir;
my @files = tar_filelist();

open2($tarout, $tarin, $tar->[0]." -c -f - --null -T - ".($tar->[1] eq "bsd" ? "-n" : "--no-recursion").compression_pipe()) or die "ERROR: failed to use tar properly (data archive): $!\n";
foreach(@files) {
	print $tarin $_,chr(0);
	$tarin->flush();
} close $tarin;
my ($archivedata, $archivesize); {
	my $o = 0;
	while(!eof $tarout) {
		$o += read $tarout, $archivedata, 1024, $o;
	}
	$archivesize = $o;
} close $tarout;

print_ar_record($ar, compressed_filename($DATAARCHIVENAME), time, 0, 0, 0100644, $archivesize);
print_ar_file($ar, $archivedata, $archivesize);

close $ar;

sub print_ar_record {
	my ($fh, $filename, $timestamp, $uid, $gid, $mode, $size) = @_;
	printf $fh "%-16s%-12lu%-6lu%-6lu%-8lo%-10ld`\n", $filename, $timestamp, $uid, $gid, $mode, $size;
	$fh->flush();
}

sub print_ar_file {
	my ($fh, $data, $size) = @_;
	syswrite $fh, $data;
	print $fh "\n" if($size % 2 == 1);
	$fh->flush();
}

sub tar_filelist {
	our @filelist;
	our @symlinks;

	find({wanted => \&wanted, no_chdir => 1}, ".");

	sub wanted {
		return if m#^./DEBIAN#;
		push @symlinks, $_ if -l;
		push @filelist, $_ if ! -l;
	}
	return (@filelist, @symlinks);
}

sub read_control_file {
	my $filename = shift;
	open(my $fh, '<', $filename) or die "ERROR: can't open control file '$filename'\n";
	my %data;
	while(<$fh>) {
		if(m/^(.*?): (.*)/) {
			$data{lc($1)} = $2;
		}
	}
	close $fh;
	return %data;
}

sub _tar_version {
	my $tar = shift;
	my $v;
	open(my $tarversionfh, '-|', "$tar --version") or return undef;
	$_ = <$tarversionfh>;
	$v = "bsd" if m/bsdtar/;
	$v = "gnu" if m/GNU/;
	close $tarversionfh;
	return [$tar, $v];
}

sub get_tar_version {
	return _tar_version('gnutar') // _tar_version('tar') // _tar_version('bsdtar')
}

sub compression_pipe {
	return "|gzip -9c" if $::compression eq "gzip";
	return "|bzip2 -9c" if $::compression eq "bzip2";
	return "|lzma -9c" if $::compression eq "lzma";
	return "";
}

sub compressed_filename {
	my $fn = shift;
	my $suffix = "";
	$suffix = ".gz" if $::compression eq "gzip";
	$suffix = ".bz2" if $::compression eq "bzip2";
	$suffix = ".lzma" if $::compression eq "lzma";
	return $fn.$suffix;
}

__END__

=head1 NAME

dm.pl

=head1 SYNOPSIS

dm.pl [options] <directory> <package>

=head1 OPTIONS

=over 8

=item B<-b>

This option exists solely for compatibility with dpkg-deb.

=item B<-ZE<lt>compressionE<gt>>

Specify the package compression type. Valid values are gzip (default), bzip2, lzma and cat (no compression.)

=item B<--help>, B<-?>

Print a brief help message and exit.

=item B<--man>

Print a manual page and exit.

=back

=head1 DESCRIPTION

B<This program> creates Debian software packages (.deb files) and is a drop-in replacement for dpkg-deb.

=cut
