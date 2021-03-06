#!/usr/bin/env perl


use Carp;
use Clone 'clone';
use strict;
use Getopt::Long;
use Pod::Usage;
use IO::File;
use Data::Dumper;
use List::MoreUtils qw(uniq);
use Bio::Tools::GFF;
use BILS::Handler::GFF3handler qw(:Ok);
use BILS::Handler::GXFhandler qw(:Ok);

my $start_run = time();
my $header = qq{
########################################################
# BILS 2015 - Sweden                                   #  
# jacques.dainat\@nbis.se                               #
# Please cite NBIS (www.nbis.se) when using this tool. #
########################################################
};

my %handlers;
my $gff = undef;
my $help= 0;
my $primaryTag=undef;
my $outfile=undef;

if ( !GetOptions(
    "help|h" => \$help,
    "gff|f=s" => \$gff,
    "p|t|l=s" => \$primaryTag,
    "output|outfile|out|o=s" => \$outfile))

{
    pod2usage( { -message => 'Failed to parse command line',
                 -verbose => 1,
                 -exitval => 1 } );
}

# Print Help and exit
if ($help) {
    pod2usage( { -verbose => 2,
                 -exitval => 2,
                 -message => "$header\n" } );
}
 
if ( ! (defined($gff)) ){
    pod2usage( {
           -message => "$header\nAt least 1 parameter is mandatory:\nInput reference gff file (--gff) \n\n",
           -verbose => 0,
           -exitval => 2 } );
}

# Manage $primaryTag
my @ptagList;
if(! $primaryTag or $primaryTag eq "all"){
  print "We will work on attributes from all features\n";
  push(@ptagList, "all");
}
else{
   @ptagList= split(/,/, $primaryTag);
   foreach my $tag (@ptagList){
      print "We will work on attributes from $tag feature.\n";
   }
}

# Manage input fasta file
my $format = select_gff_format($gff);
my $ref_in = Bio::Tools::GFF->new(-file => $gff, -gff_version => $format);


                #####################
                #     MAIN          #
                #####################

my %all_attributes;
my %attributes_per_level;
######################
### Parse GFF input #

#time to calcul progression
my $startP=time;
my $nbLine=`wc -l < $gff`;
$nbLine =~ s/ //g;
chomp $nbLine;
print "$nbLine line to process...\n";

my $geneName=undef;
my $line_cpt=0;
while (my $feature = $ref_in->next_feature() ) {
  $line_cpt++;


    manage_attributes($feature, \@ptagList, \%all_attributes, \%attributes_per_level);

  #Display progression
  if ((30 - (time - $startP)) < 0) {
    my $done = ($line_cpt*100)/$nbLine;
    $done = sprintf ('%.0f', $done);
        print "\rProgression : $done % processed.\n";
    $startP= time;
  }
}

#print "We added $nbNameAdded Name attributes\n";
my $out = IO::File->new();
if ($outfile) {
          $outfile=~ s/.gff//g;
          open($out, '>', $outfile.".txt") or die "Could not open file $outfile.txt $!";
}
else{
          $out->fdopen( fileno(STDOUT), 'w' );
}

# Print information by feature
my $nbFeat = scalar keys %attributes_per_level;
print $out "\nWe met ".$nbFeat." different feature types.";
foreach my $feature_type ( sort keys %attributes_per_level){
  my $nbAtt = scalar keys $attributes_per_level{$feature_type};
  print $out "\nHere the list of all the attributes tags met for the feature type <".$feature_type."> (".$nbAtt." attributes):\n";
  foreach my $attribute ( sort keys $attributes_per_level{$feature_type}){
    print $out $attribute."\n";
  }
}

# Print Global information
my $nbAtt = scalar keys %all_attributes;
print $out "\nHere the list of all the attributes tags met (".$nbAtt." attributes):\n";
foreach my $attribute ( sort keys %all_attributes){
  print $out $attribute."\n";
}


##Last round
my $end_run = time();
my $run_time = $end_run - $start_run;
print $out "\nJob done in $run_time seconds\n";

#######################################################################################################################
        ####################
         #     methods    #
          ################
           ##############
            ############
             ##########
              ########
               ######
                ####
                 ##

sub  manage_attributes{
  my  ($feature, $ptagList, $all_attributes, $attributes_per_level)=@_;

  my $primary_tag=$feature->primary_tag;

  # check primary tag (feature type) to handle
  foreach my $ptag (@$ptagList){

    if($ptag eq "all"){
      tag_from_list($feature,$all_attributes, $attributes_per_level);
    }
    elsif(lc($ptag) eq lc($primary_tag) ){
      tag_from_list($feature,$all_attributes, $attributes_per_level);
    }
  }
}

sub tag_from_list{
  my  ($feature, $all_attributes, $attributes_per_level)=@_;

  foreach my $tag ($feature->get_all_tags) {
      # create handler if needed (on the fly)
      if(! exists_keys( $all_attributes,($tag) ) ) {
        $all_attributes{$tag}++;
      }
      if(! exists_keys ( $attributes_per_level,($feature->primary_tag,$tag) ) ) {
        $attributes_per_level{$feature->primary_tag}{$tag}++;
      }

  }
}


__END__


=head1 NAME

gff3_sp_list_attributes.pl -
The script take a gff3 file as input. -
The script give information about attribute tags used within you file.

=head1 SYNOPSIS

    ./gff3_sp_list_attributes.pl -gff file.gff -p level2,cds,exon [ -o outfile ]
    ./gff3_sp_list_attributes.pl --help

=head1 OPTIONS

=over 8

=item B<--gff> or B<-f>

Input GFF3 file that will be read (and sorted)

=item B<-p>,  B<-t> or  B<-l>

primary tag option, case insensitive, list. Allow to specied the feature types that will be handled. 
You can specified a specific feature by given its primary tag name (column 3) as: cds, Gene, MrNa
You can specify directly all the feature of a particular level: 
      level2=mRNA,ncRNA,tRNA,etc
      level3=CDS,exon,UTR,etc
By default all feature are taking in account. fill the option by the value "all" will have the same behaviour.

=item B<-o> , B<--output> , B<--out> or B<--outfile>

Output GFF file.  If no output file is specified, the output will be
written to STDOUT.

=item B<-h> or B<--help>

Display this helpful text.

=back

=cut
