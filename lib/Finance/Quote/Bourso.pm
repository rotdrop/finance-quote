#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Rob Sessink <rob_ses@users.sourceforge.net>
#    Copyright (C) 2005, Morten Cools <morten@cools.no>
#    Copyright (C) 2006, Dominique Corbex <domcox@sourceforge.net>
#    Copyright (C) 2008, Bernard Fuentes <bernard.fuentes@gmail.com>
#    Copyright (C) 2009, Erik Colson <eco@ecocode.net>
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
#    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
#    02111-1307, USA
#
#
# This code derived from Padzensky's work on package Finance::YahooQuote,
# but extends its capabilites to encompas a greater number of data sources.
#
#
# Changelog
#
# 2014-01-12  Arnaud Gardelein
#
#     *       changes on website
#
# 2009-04-12  Erik Colson
#
#     *       Major site change.
#
# 2008-11-09  Bernard Fuentes
#
#     *       changes on website
#
# 2006-12-26  Dominique Corbex <domcox@sourceforge.net>
#
#     * (1.4) changes on web site
#
# 2006-09-02  Dominique Corbex <domcox@sourceforge.net>
#
#     * (1.3) changes on web site
#
# 2006-06-28  Dominique Corbex <domcox@sourceforge.net>
#
#     * (1.2) changes on web site
#
# 2006-02-22  Dominique Corbex <domcox@sourceforge.net>
#
#     * (1.0) iniial release
#

require 5.005;

use strict;
use warnings;

package Finance::Quote::Bourso;

use vars qw( $Bourso_URL);

use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TreeBuilder
    ;    # Boursorama doesn't put data in table elements anymore but uses <div>
use JSON qw( decode_json );

# VERSION

my $Bourso_URL = 'http://www.boursorama.com';

sub methods {
    return ( france => \&bourso,
             bourso => \&bourso,
             europe => \&bourso,
             tradegate => \&bourso_tradegate,
             lse => \&bourso_lse,
             xetra => \&bourso_xetra,
             nasdaq => \&bourso_nasdaq,
             ebs => \&bourso_ebs
    );
}
{
    my @labels =
        qw/name last date isodate p_change open high low close volume currency method exchange/;

    sub labels {
        return ( france => \@labels,
                 bourso => \@labels,
                 europe => \@labels
        );
    }
}

sub bourso_to_number {
    my $x = shift(@_);
    $x =~ s/\s//g;    # remove spaces etc in number
    return $x;
}

sub bourso_lse {
    return bourso_quotes("lse", @_);
}

sub bourso_xetra {
    return bourso_quotes("xetra", @_);
}

sub bourso_nasdaq {
    return bourso_quotes("nasdaq", @_);
}

sub bourso_ebs {
    return bourso_quotes("ebs", @_);
}

sub bourso_tradegate {
    return bourso_quotes("tradegate", @_);
}

sub bourso {
    return bourso_quotes("", @_);
}

sub bourso_quotes {
    my $bourse = shift;
    my $quoter = shift;
    my @stocks = @_;
    my ( %info, $reply, $url, $te, $ts, $row, $style );
    my $ua = $quoter->user_agent();

    $url = $Bourso_URL;

    foreach my $stocks (@stocks) {

        my $queryUrl = $url . '/recherche/' . $stocks;

        $reply = $ua->request( GET $queryUrl);
        #print "URL=".$queryUrl."\n";

        unless ( $reply->is_success ) {
            $info{ $stocks, "success" }  = 0;
            $info{ $stocks, "errormsg" } = "Error retreiving $stocks";
            next;
        }

        my $tree = HTML::TreeBuilder->new_from_content( Encode::decode_utf8( $reply->content ) );

        unless ($bourse eq "") {

            my @titleLine = $tree->look_down( "_tag", "title");
            unless (@titleLine) {
                $info{ $stocks, "success" }  = 0;
                $info{ $stocks, "errormsg" } = "Error retreiving $stocks";
                next;
            }

            my $title = $titleLine[0]->as_text;
            unless ($title =~ qr/$bourse/i) {

                my $queryBoursesUrl = $url . "/bourse/cours/ajax/autres-places-de-quotation/" . $stocks;
                $reply = $ua->request( GET $queryBoursesUrl);
                #print "URL=".$queryBoursesUrl."\n";

                unless ( $reply->is_success ) {
                    $info{ $stocks, "success" }  = 0;
                    $info{ $stocks, "errormsg" } = "Error retreiving $stocks";
                    next;
                }

                $tree->delete;
                $tree = HTML::TreeBuilder->new_from_content( Encode::decode_utf8( $reply->content ) );

                # <a href="/cours/1zTL0/" title="Nom de place boursière" class="c-link   c-link--animated / o-ellipsis">XETRA</a>
                my @bourses = $tree->look_down( "_tag", "a", "title", qr/Nom de place bours/);
                #print Dumper(\@bourses);

                $queryUrl = "";
                foreach my $bourseLink (@bourses) {

                    my $bourseName = $bourseLink->as_text;
                    if ($bourseName =~ qr/$bourse/i) {
                        $queryUrl = $url . $bourseLink->attr('href');
                        #print "url: ".$bourseLink->as_text.": ".$queryUrl."\n";
                        last;
                    }
                }

                unless ($queryUrl ne "") {
                    $info{ $stocks, "success" }  = 0;
                    $info{ $stocks, "errormsg" } = "Stock name $stocks on bourse $bourse not found";
                    next;
                }

                $reply = $ua->request( GET $queryUrl);
                #print "URL=".$queryUrl."\n";

                unless ( $reply->is_success ) {
                    $info{ $stocks, "success" }  = 0;
                    $info{ $stocks, "errormsg" } = "Error retreiving $stocks";
                    next;
                }

                $tree = HTML::TreeBuilder->new_from_content( Encode::decode_utf8( $reply->content ) );

            }

        }

        # print $reply->content;
        $info{ $stocks, "success" } = 1;

        # retrieve SYMBOL
        my @symbolline = $tree->look_down( 'class', 'c-faceplate__isin' );

        unless (@symbolline) {
            $info{ $stocks, "success" }  = 0;
            $info{ $stocks, "errormsg" } = "Stock name $stocks not found";
            next;
        }

        my $symbol = ( $symbolline[0]->content_list )[0];


        ($symbol) = ( $symbol =~ m/(\w+)/ );
        $info{ $stocks, "symbol" } = $symbol;

        # retrieve NAME
        my @nameline = $tree->look_down( 'class', 'c-faceplate__company-link' );

        unless (@nameline) {
            $info{ $stocks, "success" } = 0;
            $info{ $stocks, "errormsg" } =
              "Stock name $stocks not retrievable";
            next;
        }

        my $name = $nameline[0]->as_text;
        $name =~ s/^\s+|\s+$//g;
        $info{ $stocks, "name" } = $name;

        # set method
        $info{ $stocks, "method" } = "bourso";

        # In principle we have everything but the currency as JSON
        my @jsondata_ = JSON::decode_json($nameline[0]->attr_get_i('data-ist-init'));
        my %jsondata = %{ $jsondata_[0] };
        #print Dumper(\%jsondata);

        unless ($jsondata{ 'last' }) {
            $info{ $stocks, "success" } = 0;
            $info{ $stocks, "errormsg" } =
              "Stock price of $stocks not retrievable";
            next;
        }

        # get currency from displayed "last"
        my @curline = $tree->look_down('class', 'c-faceplate__price-currency');
        unless (@curline) {
            $info{ $stocks, "success" } = 0;
            $info{ $stocks, "errormsg" } =
              "Stock currency of $stocks not retrievable";
            next;
        }
        my $currency = $curline[0]->as_text;
        $currency =~ s/^\s+|\s+$//g;

        #print "CUR '$currency'\n";
        $info{ $stocks, "currency" } = $currency;
        $info{ $stocks, "last" } = $jsondata{ "last" };
        $info{ $stocks, "date" } = substr($jsondata{ "tradeDate" }, 0, 10);
        $info{ $stocks, "isodate" } = substr($jsondata{ "tradeDate" }, 0, 10);
        $quoter->store_date( \%info, $stocks,
                             {
                              isodate => $info{ $stocks, "date" } } );
        $info{ $stocks, "time" } = substr($jsondata{ "tradeDate" }, 11, 8);
        $info{ $stocks, "volume" } = $jsondata{ 'totalVolume' };
        $info{ $stocks, "high" } = $jsondata{ 'high' };
        $info{ $stocks, "low" } = $jsondata{ 'low' };
        $info{ $stocks, "previous" } = $jsondata{ 'previousClose' };

        delete $info{ $stocks, "errormsg" };

        $tree->delete;
    }
    return wantarray() ? %info : \%info;
}
1;

=head1 NAME

Finance::Quote::Bourso Obtain quotes from Boursorama.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("bourso","ml");  # Only query Bourso
    %info = Finance::Quote->fetch("france","af"); # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from the "Paris Stock Exchange",
http://www.boursorama.com. All stocks are available.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicity by placing "bourso" in the argument
list to Finance::Quote->new().

This module provides both the "bourso" and "france" fetch methods.
Please use the "france" fetch method if you wish to have failover
with future sources for French stocks. Using the "bourso" method
will guarantee that your information only comes from the Paris Stock Exchange.

Information obtained by this module may be covered by www.boursorama.com
terms and conditions See http://www.boursorama.com/ for details.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Bourso :
name, last, date, p_change, open, high, low, close, nav,
volume, currency, method, exchange, symbol.

=head1 SEE ALSO

Boursorama (french web site), http://www.boursorama.com

=cut
