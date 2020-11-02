# List of "static" MAC bindings
:global shost50EC501E9E29 "RoboRock-S6"
:global shostF877B8964CAC "SamsungTV-65"

# When "1" addition and removal of DNS entries is always done also for non-FQDN hostname
:local dnsAlwaysNonfqdn "1"

:local domain "lan";
:local ttl "00:05:00"

:local hostname
:local ip
:local dnsip
:local dhcpip
:local dnsnode
:local dhcpnode

:log info ("Cleaning static DNS entries.");

/ip dns static;
:foreach i in=[find where name ~ (".*\\.".$domain) ] do={
    :set hostname [ get $i name ];
    :set hostname [ :pick $hostname 0 ( [ :len $hostname ] - ( [ :len $domain ] + 1 ) ) ];
    /ip dhcp-server lease;
    :set dhcpnode [ find where host-name=$hostname ];
    :if ( $hostname = "router" || [ :len $dhcpnode ] > 0 ) do={
        :log info ("Lease for ".$hostname." still exists. Not deleting.");
    } else={
        # there's no lease by that name. Maybe this mac has a static name.
        :local found false
        /system script environment
        :foreach n in=[ find where name ~ "shost[0-9A-F]+" ] do={
            :if ( [ get $n value ] = $hostname ) do={
                :set found true;
            }
        }
        :if ( found ) do={
            :log debug ("Hostname ".$hostname." is static");
        } else={
            :log info ("Lease expired for ".$hostname.", deleting DNS entry.");
            /ip dns static remove $i;
        }
    }
}

/ip dhcp-server lease;
:foreach i in=[find] do={
    :set hostname ""
    :local mac
    :set dhcpip [ get $i address ];
    :set mac [ get $i mac-address ];
    :local comment "";
    :while ($mac ~ ":") do={
        :local pos [ :find $mac ":" ];
        :set mac ( [ :pick $mac 0 $pos ] . [ :pick $mac ($pos + 1) 999 ] );
    };
    :foreach n in=[ /system script environment find where name=("shost" . $mac) ] do={
        :set hostname [ /system script environment get $n value ];
        :set comment ( "For MAC: " . $mac );
    }
    :if ( [ :len $hostname ] = 0) do={
        :set hostname [ get $i host-name ];
    }
    :if ( [ :len $hostname ] > 0) do={
        :local hostnames [ :toarray ( $hostname . "." . $domain ) ];
        :if ($dnsAlwaysNonfqdn = "1") do={
            # Add non-FQDN hostname to hostnames list
            :set hostnames [ :put ( $hostnames, $hostname ) ];
        }
        
        /ip dns static;
        :foreach h in=$hostnames do={
            :set dnsnode [ find where name=$h ];
            :if ( [ :len $dnsnode ] > 0 ) do={
                # it exists. Is its IP the same?
                :set dnsip [ get $dnsnode address ];
                :if ( $dnsip = $dhcpip ) do={
                    :log debug ("DNS entry for " . $h . " does not need updating.");
                } else={
                    :log info ("Replacing DNS entry for " . $h);
                    /ip dns static remove $dnsnode;
                    /ip dns static add name=$h address=$dhcpip ttl=$ttl;
                }
            } else={
                # it doesn't exist. Add it
                :log info ("Adding new DNS entry for " . $h);
                /ip dns static add name=$h address=$dhcpip ttl=$ttl comment=$comment;
            }
        }
    }
}