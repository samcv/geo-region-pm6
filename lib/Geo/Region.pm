class Geo::Region;

my %children_of = (
    # regions of subregions
    '001' => <002 009 019 142 150>,
    '002' => <011 014 015 017 018>,
    '003' => <013 021 029>,
    '009' => <053 054 057 061 QO>,
    '019' => <003 005 013 021 029 419>,
    '142' => <030 034 035 143 145>,
    '150' => <039 151 154 155 EU>,
    '419' => <005 013 029>,
    # regions of countries and territories
    '005' => <AR BO BR CL CO EC FK GF GY PE PY SR UY VE>,
    '011' => <BF BJ CI CV GH GM GN GW LR ML MR NE NG SH SL SN TG>,
    '013' => <BZ CR GT HN MX NI PA SV>,
    '014' => <BI DJ ER ET KE KM MG MU MW MZ RE RW SC SO TZ UG YT ZM ZW>,
    '015' => <DZ EA EG EH IC LY MA SD SS TN>,
    '017' => <AO CD CF CG CM GA GQ ST TD ZR>,
    '018' => <BW LS NA SZ ZA>,
    '021' => <BM CA GL PM US>,
    '029' => <AG AI AN AW BB BL BQ BS CU CW DM DO GD GP HT JM KN KY LC MF MQ MS PR SX TC TT VC VG VI>,
    '030' => <CN HK JP KP KR MN MO TW>,
    '034' => <AF BD BT IN IR LK MV NP PK>,
    '035' => <BN BU ID KH LA MM MY PH SG TH TL TP VN>,
    '039' => <AD AL BA CS ES GI GR HR IT ME MK MT PT RS SI SM VA XK YU>,
    '053' => <AU NF NZ>,
    '054' => <FJ NC PG SB VU>,
    '057' => <FM GU KI MH MP NR PW>,
    '061' => <AS CK NU PF PN TK TO TV WF WS>,
    '143' => <KG KZ TJ TM UZ>,
    '145' => <AE AM AZ BH CY GE IL IQ JO KW LB NT OM PS QA SA SY TR YD YE>,
    '151' => <BG BY CZ HU MD PL RO RU SK SU UA>,
    '154' => <AX DK EE FI FO GB GG IE IM IS JE LT LV NO SE SJ>,
    '155' => <AT BE CH DD DE FR FX LI LU MC NL>,
    'EU'  => <AT BE BG CY CZ DE DK EE ES FI FR GB GR HR HU IE IT LT LU LV MT NL PL PT RO SE SI SK>,
    'QO'  => <AC AQ BV CC CP CX DG GS HM IO TA TF UM>,
);

# codes excluded from country list due to being deprecated or grouping container
my $noncountries = set <
    AN BU CS DD FX NT SU TP YD YU ZR
    EU QO
>;

# deprecated aliases
my %alias_of = :QU<EU>, :UK<GB>;

sub coerce_regions (*@regions) {
    return @regions\
        .map( *.can('values') && *.values )\
        .grep( *.defined )\
        .map({ /^ <[0..9]> ** 1..2 $/ ?? .fmt('%03d') !! .uc })\
        .map({ %alias_of{$_} || $_ });
}

has @!includes;
has @!excludes;
has @!countries;
has $!children;
has $!parents;

submethod BUILD (:$include, :$exclude) {
    @!includes = coerce_regions($include);
    @!excludes = coerce_regions($exclude);
}

method !children () {
    $!children ||= do {
        my sub build_children (@regions) {
            @regions.map: {
                $^region,
                %children_of{$^region}:exists
                    ?? build_children(%children_of{$^region})
                    !! ()
            }
        }

        my $excludes = build_children(@!excludes).Set;
        build_children(@!includes).grep({ !$excludes{$_} }).Set;
    };

    return $!children;
}

method !parents () {
    $!parents ||= do {
        my sub build_parents (@regions) {
            @regions.map: -> $region {
                $region,
                build_parents(%children_of.keys.grep: {
                    %children_of{$_}.any eq $region
                })
            }
        }

        my %count;
        build_parents(@!includes).grep({
            ++%count{$_} == @!includes.elems
        }).Set;
    };

    return $!parents;
}

method contains (*@regions) {
    return ?self!children{ coerce_regions(@regions).all };
}

method is_within (*@regions) {
    return ?self!parents{ coerce_regions(@regions).all };
}

method countries () {
    @!countries ||= self!children.keys.grep({
        /<[A..Z]>/ && !$noncountries{$_}
    }).sort;

    return @!countries.values;
}

=begin pod

=head1 NAME

Geo::Region - Geographical regions and groupings using UN M.49 and CLDR data

=head1 VERSION

This document describes Geo::Region for Perl 6, built with Unicode CLDR v26.

=head1 SYNOPSIS

    use Geo::Region;
    use Geo::Region::Constant;

    $amer = Geo::Region.new(include => AMERICAS);
    $emea = Geo::Region.new(include => (EUROPE, WESTERN_ASIA, AFRICA));
    $apac = Geo::Region.new(include => (ASIA, OCEANIA),
                            exclude => WESTERN_ASIA);

    if $amer.contains($country) {
        # country is in the Americas (US, MX, BR, etc.)
    }
    elsif $emea.contains($country) {
        # country is in Europe, the Middle East, and Africa (FR, SA, ZW, etc.)
    }
    elsif $apac.contains($country) {
        # country is in Asia-Pacific (JP, TH, AU, etc.)
    }

=head1 DESCRIPTION

This class is used to create geographical regions and groupings of subregions
and countries. Default regional groupings are provided using the L<Unicode CLDR
v26 Territory
Containment|http://unicode.org/cldr/charts/26/supplemental/territory_containment_un_m_49.html>
data, which is an extension of the United Nations L<UN
M.49 (Rev.3)|http://unstats.un.org/unsd/methods/m49/m49regin.htm> standard.

=head2 Regions

Regions and subregions are represented with UN M.49 region codes, such as B<419>
for Latin America and B<035> for Southeast Asia. Either the official format
using a three-digit C<0>-padded string like C<'035'> or an integer like C<35>
may be used with this class. Note when using the C<0>-padded format that it must
be quoted as a string so as not to be treated as on octal literal. The CLDR also
adds two additional two-letter region codes which are supported: B<EU> for the
European Union and B<QO> for Outlying Oceania. These region codes are all
available as constants in L<Geo::Region::Constant>.

=head2 Countries

Countries and territories are represented with ISO 3166-1 alpha-2 country codes,
such as B<JP> for Japan and B<AQ> for Antarctica, and are case insensitive.
Unlike with region codes, the three-digit forms of country codes are not
currently supported, nor are three-letter codes. The deprecated code B<UK> for
the United Kingdom is supported as an alias of the official code B<GB>.

=head2 Constructor

The C<new> class method is used to construct a Geo::Region object along with the
C<include> argument and optional C<exclude> argument.

=begin item
C<include>

Accepts either a single region code or an array reference of region or country
codes to be included in the resulting custom region.

    # countries in the European Union (EU)
    Geo::Region.new(include => EUROPEAN_UNION)

    # countries in Asia (142) plus Russia (RU)
    Geo::Region.new(include => (ASIA, 'RU'))

=end item

=begin item
C<exclude>

Accepts values in the same format as C<include>. This can be used to exclude
countries or subregions from a region.

    # countries in Europe (150) which are not in the European Union (EU)
    Geo::Region.new(include => EUROPE, exclude => EUROPEAN_UNION)

=end item

=head2 Methods

=begin item
C<contains>

Given a country or region code, determines if the region represented by the
Geo::Region instance contains it.

    if $region.contains($country) {

=end item

=begin item
C<is_within>

Given a region code, determines if all the countries and regions represented by
the Geo::Region instance are within it.

    if $subregion.is_within($region) {

=end item

=begin item
C<countries>

Returns a list of country codes of the countries within the region represented
by the Geo::Region instance.

    for $region.countries -> $country {

=end item

=head1 SEE ALSO

=item L<Geo::Region::Constant> — Constants for UN M.49 and CLDR region codes
=item L<Unicode CLDR: UN M.49 Territory
Containment|http://unicode.org/cldr/charts/26/supplemental/territory_containment_un_m_49.html>
=item L<United Nations: UN M.49 Standard Country, Area, & Region
Codes|http://unstats.un.org/unsd/methods/m49/m49regin.htm>
=item L<Geo::Region> for Perl 5

=head1 AUTHOR

Nick Patch <patch@cpan.org>

=head1 COPYRIGHT AND LICENSE

© 2014 Nick Patch

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=end pod
