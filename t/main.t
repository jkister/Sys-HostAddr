#!/usr/local/bin/perl

# Sys::HostAddr main.t
# Copyright (c) 2010-2018 Jeremy Kister.
# Released under the Artistic License 2.0

BEGIN {
    #https://rt.cpan.org/Public/Bug/Display.html?id=82629
    $ENV{LC_ALL} = 'C';
};

use strict;
use Test::More tests => 9;

use IO::Socket::SSL;
use Sys::HostAddr;

my $sysaddr = Sys::HostAddr->new( debug => 0 );

ok( $sysaddr->{class} eq 'Sys::HostAddr', "testing Sys::HostAddr v$Sys::HostAddr::VERSION on platform: $^O" );

my $main_ip = $sysaddr->main_ip();
ok( $main_ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/, "Main IP Address appears to be: $main_ip" );

my $first_ip = $sysaddr->first_ip();
ok( $first_ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/, "First IP Adddress is: $first_ip" );

# public() should return undef gracefully when given a bogus host (no crash)
my $bad = Sys::HostAddr->new();
{
    no warnings 'redefine';
    local *IO::Socket::SSL::new  = sub { return undef };
    local $SIG{__WARN__}         = sub {};
    my $result = $bad->public();
    ok( !defined($result), "public() returns undef on connection failure" );
}

# _ipv must be per-instance, not shared across objects
my $s4 = Sys::HostAddr->new( ipv => 4 );
my $s6 = Sys::HostAddr->new( ipv => 6 );
ok( $s4->{_ipv} ne $s6->{_ipv}, "IPv4 and IPv6 instances have distinct _ipv values" );

SKIP: {
    my $probe = IO::Socket::SSL->new(PeerAddr => 'www.dnsbyweb.com',
                                     PeerPort => 443,
                                     Timeout  => 5);
    skip "www.dnsbyweb.com unreachable", 1 unless $probe;
    close $probe;

    my $pub = $sysaddr->public();
    ok( defined($pub) && $pub =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/,
        "public() returned a valid IPv4 address: " . ($pub // 'undef') );
}
    
my $href = $sysaddr->ip();
my $info = "IP info:\n";
my $i = 0;
my $a = 0;
foreach my $interface ( keys %{$href} ){
    $i++ unless ($interface =~ /^lo\d*/);
    foreach my $aref ( @{$href->{$interface}} ){
        $info .= "$interface: $aref->{address}/$aref->{netmask}\n";
        $a++ unless($aref->{address} =~ /^127\./);
    }
}
ok( $i && $a, $info );

my $addrs;
my $addr_aref = $sysaddr->addresses();
foreach my $address ( @{$addr_aref} ){
    $addrs .= "Found IP address: $address\n";
}
ok( @{$addr_aref} > 0, $addrs ); # 127.0? + other - win32 doesnt include 127

my $ints;
my $int_aref = $sysaddr->interfaces();
foreach my $interface ( @{$int_aref} ){
    $ints .= "Found interface: $interface\n";
}
ok( @{$int_aref} > 0, $ints );

