#!/usr/bin/env perl
#
use warnings;
use strict;
use Cpanel::JSON::XS;
#use DataBrowser qw(browse);

open IN, "-";

my $json = "";
while (my $line = <IN>) {
	chomp $line;
	$json .= $line;

}

my $out = decode_json($json);

my $encoder = Cpanel::JSON::XS->new->ascii->pretty->allow_nonref;
$encoder = $encoder->canonical([1]);

foreach my $array (@{$out->{'rows'}}) {
	my @taxa = split /\|/, $array->{'id'};
	my @newTaxa;
	foreach my $taxaName (@taxa) {
		if ($taxaName =~ m/k__/) {
			$taxaName =~ s/k__//g;
		} else {
			$taxaName =~ s/^.//g;
		}
		push @newTaxa, $taxaName;
	}
	$array->{'metadata'}->{'taxonomy'} = \@newTaxa;
}
my $jsonOut = $encoder->encode($out);
print "$jsonOut";
