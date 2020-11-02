# When "1" all DNS entries with IP address of DHCP lease are removed
:local dnsRemoveAllByIp "1"

# When "1" all DNS entries with hostname of DHCP lease are removed
:local dnsRemoveAllByName "1"

# When "1" addition and removal of DNS entries is always done also for non-FQDN hostname
:local dnsAlwaysNonfqdn "0"

# DNS domain to add after DHCP client hostname
:local dnsDomain "lan"

# DNS TTL to set for DNS entries
:local dnsTtl "00:15:00"

# Source of DHCP client hostname, can be "lease-hostname" or any other lease attribute, like "host-name" or "comment"
:local leaseClientHostnameSource "lease-hostname"

:local leaseClientHostname
:if ($leaseClientHostnameSource = "lease-hostname") do={
  :set leaseClientHostname $"lease-hostname"
} else={
  :set leaseClientHostname ([:pick \
    [/ip dhcp-server lease print as-value where server="$leaseServerName" address="$leaseActIP" mac-address="$leaseActMAC"] \
    0]->"$leaseClientHostnameSource")
}

:local leaseClientHostnames "$leaseClientHostname"
:if ([:len [$dnsDomain]] > 0) do={
  :if ($dnsAlwaysNonfqdn = "1") do={
    :set leaseClientHostnames "$leaseClientHostname.$dnsDomain,$leaseClientHostname"
  } else={
    :set leaseClientHostnames "$leaseClientHostname.$dnsDomain"
  }
}

:if ($dnsRemoveAllByIp = "1") do={
  /ip dns static remove [/ip dns static find and address="$leaseActIP"]
}

:foreach h in=[:toarray value="$leaseClientHostnames"] do={
  :if ($dnsRemoveAllByName = "1") do={
    /ip dns static remove [/ip dns static find and name="$h"]
  }

  /ip dns static remove [/ip dns static find and address="$leaseActIP" and name="$h"]

  :if ($leaseBound = "1") do={
    :delay 1
    /ip dns static add address="$leaseActIP" name="$h" ttl="$dnsTtl"
  }
}