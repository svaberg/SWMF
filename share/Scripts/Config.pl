#!/usr/bin/perl -i
use strict;

our @Arguments; # Arguments obtained from the caller script
our %Remaining; # Arguments not handled by this script

&print_help if not @Arguments;

# Default compiler per machine or OS
my %Compiler = ("Linux"   => "f95",
	     "Darwin"  => "f95",
	     "OSF1"    => "f90",
	     "IRIX64"  => "f90",
	     "palm"    => "ifort",
	     "cfe1"    => "ifort",
	     "cfe2"    => "ifort",
	     "cfe3"    => "ifort"
	     );

my %Mpi = ("Linux"   => "mpich",
	"Darwin"  => "mpich",
	"OSF1"    => "mpich",
	"IRIX64"  => "SGI",
	"palm"    => "ifort",
	"cfe1"    => "ifort",
	"cfe2"    => "ifort",
	"cfe3"    => "ifort"
	);

# Default file names
my $MakefileDefOrig;
my $MakefileConf     = 'Makefile.conf';
my $MakefileConfOrig = 'share/build/Makefile.';
my $MakefileDef      = 'Makefile.def';

# Default precision for installation
my $DefaultPrecision = 'double';

# Global variables for the settings
my $Installed;             # true if code is installed ($MakefileConf exists)
my $OS='unknown';          # operating system in $MakefileDef
my $DIR='unknown';         # main directory for code in $MakefileDef
my $Compiler;              # Non default F90 compiler in $MakefileConf
my $MpiVersion;            # Non default MPI version for mpif90.h
my $Precision='unknown';   # Precision set in $MakefileConf
my $IsComponent=0;         # True if code is installed as a component of SWMF
my $Code;                  # The name of the code
my $Component;             # The SWMF component the code is representing
my $WARNING;               # First part of warning messages
my $ERROR;                 # First part of error messages
my $Verbose;               # Verbose information is printed if true

# Default values for the various actions
my $Install;
my $Uninstall;
my $Show;
my $ShowLong;
my $NewPrecision;
my $DryRun;
my $IsCompilerSet;
my $Debug;
my $Optimize;

# Obtain $OS and $DIR
$OS  = `uname`    or die "$ERROR: could not obtain OS\n";
chomp $OS;
$DIR = `/bin/pwd` or die "$ERROR: could not obtain DIR\n";
chomp $DIR;

# Set default compiler
my $Machine = `uname -s`; chop $Machine;

$Compiler = $Compiler{$Machine} or $Compiler = $Compiler{$OS} or
    die "$ERROR: default compiler is not known for OS=$OS\n";

# Guess the names of the component and the code
($Component, $Code) = ($DIR =~ /([A-Z][A-Z])\/([^\/]+)$/);

# Obtain current settings
&get_settings_;

# Show current settings if no -... arguments are given.
$Show = 1 if not grep /^\-/, @Arguments;

# Set actions based on the switches
foreach (@Arguments){
    if(/^-dryrun$/)           {$DryRun=1;                       next};
    if(/^-show$/i)            {$ShowLong=1;                     next};
    if(/^-verbose$/i)         {$Verbose=1;                      next};
    if(/^-h(elp)?$/i)         {&print_help_;                    next};
    if(/^-(single|double)$/i) {$NewPrecision=lc($1);            next};
    if(/^-install(=.*)?$/)    {my $value=$1;
                               $IsComponent=1 if $value =~ /^=c/i;
			       $IsComponent=0 if $value =~ /^=s/i;
			       $Install=1;                      next};
    if(/^-uninstall$/i)       {$Uninstall=1;                    next};
    if(/^-compiler=(.*)$/i)   {$Compiler=$1; $IsCompilerSet=1;  next};
    if(/^-mpi=(.*)$/i)        {$MpiVersion=$1;                  next};
    if(/^-standalone$/i)      {$IsComponent=0;                  next};
    if(/^-component$/i)       {$IsComponent=1;                  next};
    if(/^-debug$/i)           {$Debug=1;                        next};
    if(/^-nodebug$/i)         {$Debug=0;                        next};
    if(/^-O([0-4])$/i)        {$Optimize=$1;                    next};  
    if(/^.*$MakefileDef$/)    {$MakefileDefOrig=$_;             next};
    if(not /^-/)              {($Component,$Code) = split '/';  next};

    $Remaining{$_}=1;
}

if($Uninstall){
    if(not $Installed){
	warn "$ERROR: $Code is not installed.\n";
	exit 1;
    }else{
	&shell_command("make distclean");
	exit 0;
    }
}

# Execute the actions in the appropriate order
&install_code_ if $Install;

&set_precision_;

if($Show){
    &get_settings_;
    &show_settings_;
}

##############################################################################
sub get_settings_{

    $WARNING = "!!! $Code:config.pl WARNING:";
    $ERROR   = "!!! $Code:config.pl ERROR:";

    $Installed = (-e $MakefileConf and -e $MakefileDef);

    return if not $Installed;

    # Set defaults/initial values
    $Precision   = "single";

  TRY:{
      # Read information from $MakefileDef
      open(MAKEFILE, $MakefileDef)
	  or die "$ERROR could not open $MakefileDef\n";

      while(<MAKEFILE>){
	  if(/^\s*include\s+(.*$MakefileDef)\s*$/){
	      $MakefileDef = $1;
	      $IsComponent = 1;
	      close MAKEFILE;
	      redo TRY;
	  }
	  $OS         = $1 if /^\s*OS\s*=\s*(\w+)/;
      }
      close(MAKEFILE);
  }

  TRY:{
      # Read information from $MakefileConf
      open(MAKEFILE, $MakefileConf)
	  or die "$ERROR could not open $MakefileConf\n";

      while(<MAKEFILE>){
	  if(/^\s*include\s+(.*$MakefileConf)\s*$/){
	      $MakefileConf = $1;
	      close MAKEFILE;
	      redo TRY;
	  }
	  $Compiler = $+ if /^\s*COMPILE.f90\s*=\s*(\$\{CUSTOMPATH_F\})?(\S+)/;
	  $Precision = "double" if 
	      m/^\s*PRECISION\s*=\s*
	      (\-r8|\-real_size\s*64|\-\-dbl|\-qautodbl=dbl4)/x;
      }
  }
    close(MAKEFILE);
}

##############################################################################

sub show_settings_{

    if(not $Installed){
	print "$Code is not installed\n";
	exit 0;
    }

    print "\n";
    if($IsComponent){
	print "$Code is installed in directory $DIR as an SWMF component.\n";
    }else{
	print "$Code is installed in directory $DIR.\n";
    }
    print "The installation is for the $OS operating system.\n";
    print "The selected F90 compiler is $Compiler.\n";
    print "The default precision for reals is $Precision precision.\n";

    print "\n";

}

##############################################################################
sub install_code_{

    my $Text = $Installed ? "Reinstalling $Code" : "Installing $Code";
    $Text .= " as an SWMF component" if $IsComponent;  
    print "$Text\n";

    if($IsComponent){
	my $dir = $DIR; $dir =~ s|/[^/]*/[^/]*$||;  # go two directories up
	my $makefile = "$dir/$MakefileDef";          # makefile to be included
	die "$ERROR: could not find file $makefile\n" unless -f $makefile;
	&shell_command("echo include $makefile > $MakefileDef");

	$makefile = "$dir/$MakefileConf"; # makefile to be included
	die "$ERROR: could not find file $makefile\n" unless -f $makefile;
	&shell_command("echo include $makefile > $MakefileConf");
    }else{
	die "$ERROR: original $MakefileDef is not given\n" unless
	    $MakefileDefOrig;
	die "$ERROR: $MakefileDefOrig is missing\n" unless
	    -f $MakefileDefOrig;
	&shell_command("echo OS=$OS > $MakefileDef");
	&shell_command("echo SWMF_ROOT=$DIR >> $MakefileDef");
	&shell_command("echo UADIR=$DIR >> $MakefileDef");
	&shell_command("cat $MakefileDefOrig >> $MakefileDef");
	&shell_command("cat $MakefileConfOrig$OS$Compiler > $MakefileConf");
    }

    # Read info from main Makefile.def
    &get_settings_;

    # Install the code
    my $command = "make install";
    $command .= " COMPILER='$Compiler'" if $IsCompilerSet;
    $command .= " MPIVERSION='$MpiVersion'" if $MpiVersion;
    &shell_command($command);

    # Set initial precision for reals
    $NewPrecision = $DefaultPrecision unless $NewPrecision;
    &set_precision_("init");

    # Now code is installed
    $Installed = 1 unless $DryRun;
}

##############################################################################

sub set_precision_{

    # Set the precision for reals
    # If called with a true argument, initial setting is done, otherwise
    # an existing setting is changed

    my $init = $_[0];

    # Return if there is nothing to do
    return unless $init or ($NewPrecision and $NewPrecision ne $Precision);

    # Precision will be NewPrecision after changes
    $Precision = $NewPrecision;

    # clean the distribution unless initial installation is done
    &shell_command("make clean") unless $init;

    print "Setting PRECISION variable to $Precision precision in ".
	"$MakefileConf\n";
    if(not $DryRun){
	@ARGV = ($MakefileConf);
	while(<>){
	    if($OS eq "OSF1"){
		# Comment out line if in conflict with new precision
                $_="#$_" if /^\s*PRECISION\s*=\s*\-real_size\s+64/ and $Precision eq 'single'
                    or      /^\s*PRECISION\s*=\s*\-real_size\s+32/ and $Precision eq 'double';

                # Uncomment line if agrees with new precision
                s/#// if /^\s*#\s*PRECISION\s*=\s*\-real_size\s+64/ and $Precision eq 'double'
                    or   /^\s*#\s*PRECISION\s*=\s*\-real_size\s+32/ and $Precision eq 'single';

	    }else{
		# Comment out line if in conflict with new precision
		$_="#$_" if /^\s*PRECISION\s*=\s*\-/ and $Precision eq 'single'
		    or      /^\s*PRECISION\s*=\s*$/  and $Precision eq 'double';
		# Uncomment line if agrees with new precision
		s/#// if /^\s*#\s*PRECISION\s*=\s*\-/ and $Precision eq 'double'
		    or   /^\s*#\s*PRECISION\s*=\s*$/  and $Precision eq 'single';
	    }
	    print;
	}
    }
}

1;
##############################################################################

sub shell_command{

    my $command = join(' ',@_);
    print "$command\n" if $Verbose;

    return if $DryRun;

    system($command)
	and die "$ERROR Could not execute command=$command\n";
}

##############################################################################
#BOP
#!QUOTE: \subsection{Installation and Configuration with config.pl}
#!ROUTINE: config.pl - (un)installation and configuration of SWMF/components
#!DESCRIPTION:
# The config.pl provides a single uniform interface towards 
# installation, configuration and uninstallation for the SWMF and its
# components.
#
#!REVISION HISTORY:
# 12/16/2006 G. Toth - initial version based on SetSWMF.pl
#EOP
sub print_help_{

    print 
#BOC
"config.pl can be used for installing and setting various options for SWMF
or its components. The core of the script is in share/Scripts/config.pl,
and this is used by the config.pl scripts in the main SWMF and component 
directories. This help describes the options/features of the core script.
Additional features (if any) will be shown below.

This script edits the appropriate Makefile-s, copies files and executes 
shell commands. The script can also show the current settings.

Usage: config.pl [-help] [-verbose] [-show] [-dryrun] 
                 [-install[=s|=c] [-compiler=COMP] [-mpi=VERSION]] [-uninstall]
                 [-single|-double] [-debug|-nodebug] [-O0|-O1|-O2|-O3|-O4]
                 [PATH/Makefile.def] [CODENAME]

If called without options, the current settings are shown.

Information:

-h  -help      show this help message
-dryrun        dry run (do not modify anything, just show actions)
-show          show current settings in more detail.
-verbose       show verbose information.

CODE           set name of the code. Usually passed by the caller script.
               The default value is the last part of the currend directory.

(Un)installation:

-uninstall     uninstall code (make distclean)

-install=c     (re)install code as an SWMF component (c)
-install=s     (re)install code as a stand-alone (s) code
-install       install code as a stand-alone if it is not yet installed,
               or reinstall the same way as it was installed originally:
               (re)creates Makefile.conf, Makefile.def, make install

-compiler=COMP copy Makefile.conf for a non-default F90 compiler COMP
-mpi=VERSION   copy mpif90_OSVERSION into mpif90.h

PATH/Makefile.def  provides the path to the original Makefile.def file
               This information is normally passed by the calling script.
               and it is only needed for stand-alone installation.


Compilation:

-single        set precision to single in Makefile.conf and make clean
-double        set precision to double in Makefile.conf and make clean

-debug         select debug options for the compiler in Makefile.conf
-nodebug       do not use debug options for the compiler in Makefile.conf
-O0            set all optimization levels to -O0
-O1            set optimization levels to at most -O1
-O2            set optimization levels to at most -O2
-O3            set optimization levels to at most -O3
-O4            set maximum optimization level

Examples of use:

Show current settings: 

    config.pl

Show current settings with more detail: 

    config.pl -show

Install code with the ifort compiler and Altix MPI and select single precision:

    config.pl -install -compiler=ifort -mpi=Altix -single

Set optimization level to -O0 and switch on debugging flags:

    config.pl -debug -O0

Set optimization level to -03 and switch off debugging flags:

    config.pl -nodebug -O3

Uninstall code (if this fails, run config.pl -install first):

    config.pl -uninstall"
#EOC
    ,"\n\n";
}

##############################################################################

1;
