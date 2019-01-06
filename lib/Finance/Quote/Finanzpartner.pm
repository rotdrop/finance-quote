# Finance::Quote Perl module to retrieve quotes from Finanzpartner.de
#    Copyright (C) 2007  Jan Willamowius <jan@willamowius.de>
#                  2017  Claus-Justus Heine <himself@claus-justus-heine.de>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

package Finance::Quote::Finanzpartner;

use strict;
use open ':std', ':encoding(UTF-8)';
use utf8;
use Web::Query qw();

# VERSION

my $FINANZPARTNER_URL = "http://www.finanzpartner.de/fi/";

sub methods {return (finanzpartner        => \&finanzpartner);}
sub labels { return (finanzpartner=>[qw/name date price last method/]); } # TODO

# Trim leading and tailing whitespaces (also non-breakable whitespaces)
sub trim
{
	$_ = shift();
	s/&nbsp;/ /g;
	s/\240/ /g;
	s/\302/ /g;
	s/^\s*//;
	s/\s*$//;
	return $_;
}

# Convert number separators to US values
sub convert_price {
        $_ = shift;
        tr/.,/,./ ;
        return $_;
}

sub finanzpartner
{
	my $quoter = shift;     # The Finance::Quote object.
	my @stocks = @_;
	my $ua = $quoter->user_agent();
	my %info;

	foreach my $stock (@stocks) {
		$ua->agent('Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)');
		my $response = $ua->get($FINANZPARTNER_URL . $stock . '/');
		$info{$stock,"success"} = 0;
		if (!$response -> is_success()) {
			$info{$stock,"errormsg"} = "HTTP failure";
		} else {
			my $date;
			my $wkn;
			my $isin;
			my $name;
			my $exchange;
			my $lastOut;
			my $outCurrency;
			my $lastIn;
			my $inCurrency;
			my $currency;
			my $volume;
			my $volumeCurrency;

			my $parser = Web::Query->new_from_html($response->content);
			my $cols = $parser->find('.row');

			$cols->each(sub {
					    my ($i, $elem) = @_;
					    my $rows = $elem->find('.col-sm-3');

					    my $cells = $elem->find('div[class^="col-sm-"]');

					    $cells->each(sub {
								 my ($i, $elem) = @_;
								 my $text = trim($elem->text);
								 if ($text eq 'Wertpapierkennziffer:') {
									 $wkn = trim($elem->next->text);
								 } elsif ($text eq 'ISIN:') {
									 $isin = trim($elem->next->text);
								 } elsif ($text eq 'Fondsname:') {
									 $name = trim($elem->next->text);
								 } elsif ($text eq 'Investmentgesellschaft:') {
									 $exchange = trim($elem->next->text);
								 } elsif ($text eq 'Fondsvolumen:') {
									 $volume = trim($elem->next->text);
									 if ($volume =~ /([0-9]+[.][0-9]+,[0-9]+)\s*(Mio.)?\s+([A-Z]+)/) {
										 $volume = $1;
										 my $volumeUnits = $2;
										 $volumeCurrency = $3;
										 $volume = convert_price($volume);
										 $volume =~ s/,//g;
										 if ($volumeUnits eq 'Mio.') {
											 $volume *= 1e6;
										 }
									 }
								 } elsif ($text =~ /^Aktueller Kurs:.*vom ([0-9][0-9][.][0-9][0-9][.][0-9][0-9][0-9][0-9])/) {
									 $date = $1;
									 my $subCells = $elem->next->find('.col-xs-6');
									 $subCells->each(sub {
												 my ($i, $elem) = @_;
												 my $text = trim($elem->text);
												 if ($text =~ /^Ausgabe-Kurs:/) {
													 $lastOut = trim($elem->next->text);
													 if ($lastOut =~ /([0-9]+[.][0-9][0-9])\s+([A-Z]+)/) {
														 $lastOut = $1;
														 $outCurrency = $2;
													 }
												 } elsif ($text =~ /^R[^c]+cknahme-Kurs:/) {
													 $lastIn = trim($elem->next->text);
													 if ($lastIn =~ /([0-9]+[.][0-9][0-9])\s+([A-Z]+)/) {
														 $lastIn = $1;
														 $inCurrency = $2;
													 }
												 }
											 });
								 }
							 });
				    });

#			print "$stock $isin $wkn\n";
			if ($stock eq $isin || $stock eq $wkn) {
				# got it
				$info{$stock, "method"} = "finanzpartner";
				$info{$stock, "symbol"} = $stock;
				$info{$stock, "name"} = $name;
				$info{$stock, "exchange"} = $exchange;
				$info{$stock, "volume"} = $volume;
				$quoter->store_date(\%info, $stock, {eurodate => $date});
				$info{$stock, "currency"} = $inCurrency;
				$info{$stock, "price" } = $lastIn;
				$info{$stock, "last" } = $info{$stock, "price"};
				$info{$stock, "success"} = 1;
			}
		}
	}
	return wantarray ? %info : \%info;
}

1;

=head1 NAME

Finance::Quote::Finanzpartner - Obtain quotes from Finanzpartner.de.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new("Finanzpartner");

    %info = $q->fetch("finanzpartner","LU0055732977");

=head1 DESCRIPTION

This module obtains quotes from Finanzpartner.de (http://www.finanzpartner.de) by WKN or ISIN.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Finanzpartner:
exchange, name, date, price, last, method, volume.

=head1 SEE ALSO

Finanzpartner, http://www.finanzpartner.de/

Finance::Quote;

=cut
