#!/usr/local/bin/perl

# Sys::HostAddr ipv6-debian.t
# Copyright (c) 2010-2014 Jeremy Kister.
# Copyright (c) 2016-2018 Joelle Maslak
# Released under the Artistic License 2.0.

#
# Validates module on some versions of Debian that have a slightly
# modified format of ifconfig
#

BEGIN {
    $ENV{LC_ALL} = 'C';
}

use strict;
use Test::Simple tests => 23;

use Sys::HostAddr;

# Monkeypatch ifconfig so we have the output we want
local *Sys::HostAddr::ifconfig = sub {
    my $output = <<EOF
eth0      Link encap:Ethernet  HWaddr 00:09:3D:10:30:0F  
          inet addr:10.0.0.14  Bcast:10.0.0.255  Mask:255.255.255.0
          inet6 addr: 2001:db8:33::6/64 Scope:Global
          inet6 addr: fe80::209:3dff:fe10:300f/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:7144152 errors:0 dropped:0 overruns:0 frame:0
          TX packets:5458726 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:1849676368 (1.7 GiB)  TX bytes:975642847 (930.4 MiB)
          Interrupt:193 

eth1      Link encap:Ethernet  HWaddr 00:09:3D:10:30:10  
          inet addr:192.168.128.129  Bcast:192.168.131.255  Mask:255.255.252.0
          inet6 addr: 2001:db8:34::10/64 Scope:Global
          inet6 addr: 2001:db8:34::11/64 Scope:Global
          inet6 addr: fe80::209:3dff:fe10:3010/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:378122 errors:0 dropped:0 overruns:0 frame:0
          TX packets:925514 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:31414290 (29.9 MiB)  TX bytes:1367006880 (1.2 GiB)
          Interrupt:201 

eth1:1    Link encap:Ethernet  HWaddr 00:09:3D:10:30:10  
          inet addr:10.2.3.4  Bcast:10.2.3.255  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          Interrupt:201 Base address:0x100 

lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:16436  Metric:1
          RX packets:62255 errors:0 dropped:0 overruns:0 frame:0
          TX packets:62255 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:4582175 (4.3 MiB)  TX bytes:4582175 (4.3 MiB)

sit0      Link encap:IPv6-in-IPv4  
          NOARP  MTU:1480  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:0 (0.0 b)  TX bytes:0 (0.0 b)
EOF
      ;

    # Split into lines and re-add the new line
    my (@lines) = split /\n/, $output, -1;
    my (@ret) = map { "$_\n" } @lines;
    return \@ret;
};

my $sysaddr = Sys::HostAddr->new( debug => 0 );

ok( $sysaddr->{class} eq 'Sys::HostAddr',
    "testing Sys::HostAddr v$Sys::HostAddr::VERSION on platform: $^O" );

my $first_ip = $sysaddr->first_ip();
ok( $first_ip eq '10.0.0.14', "First IP Adddress is: $first_ip" );

my (@find) = (
    '2001:db8:33::6',           'fe80::209:3dff:fe10:300f',
    '2001:db8:34::10',          '2001:db8:34::11',
    'fe80::209:3dff:fe10:3010', '::1',
);

$sysaddr = Sys::HostAddr->new( debug => 0, ipv => 6 );

my $addresses = $sysaddr->addresses();
my $numaddr   = scalar(@$addresses);
my $numfind   = scalar(@find);
ok( $numaddr == $numfind, "Proper number of address() responses ($numaddr == $numfind)" );

my $i = 0;
foreach my $addr (@find) {
    my $match = shift(@$addresses);
    if ( !defined($match) ) { $match = 'undef'; }

    ok( $match eq $addr, "Testing that address() $i is $addr (found $match)" );
    $i++;
}

my $href    = $sysaddr->ip();
my $numkeys = scalar( keys %$href );
ok( $numkeys == 3, "Proper number of ip() interfaces ($numkeys == 3)" );
ok( ( join '|', sort keys %$href ) eq 'eth0|eth1|lo', 'Proper interfaces found by ip()' );

my @checks = (
    'lo|0|::1|/128',                       'eth0|0|2001:db8:33::6|/64',
    'eth0|1|fe80::209:3dff:fe10:300f|/64', 'eth1|0|2001:db8:34::10|/64',
    'eth1|1|2001:db8:34::11|/64',          'eth1|2|fe80::209:3dff:fe10:3010|/64',
);
foreach my $check (@checks) {
    my ( $iface, $index, $addr, $mask ) = split /\|/, $check;

    my $testaddr = $href->{$iface}[$index]{address};
    my $testmask = $href->{$iface}[$index]{netmask};

    ok( $testaddr eq $addr, "Proper address on $iface at index $index: got $testaddr" );
    ok( $testmask eq $mask, "Proper netmask on $iface at index $index: got $testmask" );
}

