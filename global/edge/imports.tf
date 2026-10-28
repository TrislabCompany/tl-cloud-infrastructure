# Google Workspace's set-up re-created the Gmail MX records and the SPF of
# trislab.com in the dashboard on 2026-10-28, with new IDs, so they are taken
# into the state instead of being created again. Once applied, these blocks do
# nothing and can be removed.

import {
  to = cloudflare_dns_record.this["trislab.com/trislab.com/mx-aspmx"]
  id = "bcda485574dc48b46934729d44ccbaf4/a91001b0fbcc9a92be7c421040000e35"
}

import {
  to = cloudflare_dns_record.this["trislab.com/trislab.com/mx-alt1"]
  id = "bcda485574dc48b46934729d44ccbaf4/3a2682468de82a2af50627c5c151efae"
}

import {
  to = cloudflare_dns_record.this["trislab.com/trislab.com/mx-alt2"]
  id = "bcda485574dc48b46934729d44ccbaf4/9d3cb847e8c75ced7a6c39c5c108df6d"
}

import {
  to = cloudflare_dns_record.this["trislab.com/trislab.com/mx-alt3"]
  id = "bcda485574dc48b46934729d44ccbaf4/deab227694fe99402168069c8f04e8cc"
}

import {
  to = cloudflare_dns_record.this["trislab.com/trislab.com/mx-alt4"]
  id = "bcda485574dc48b46934729d44ccbaf4/dce957a91cfb36e7e34f04d1f4f194ec"
}

import {
  to = cloudflare_dns_record.this["trislab.com/trislab.com/spf"]
  id = "bcda485574dc48b46934729d44ccbaf4/76c3e403f6e7c21c0ff83cfb007543ec"
}
