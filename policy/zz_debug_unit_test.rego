package catalog

test_zz_1 if {
	denies(with_site_hostname("prod-corporate-site.trislab.com"), "the hostname prod-corporate-site.trislab.com is used more than once")
}

test_zz_2 if {
	denies(with_site_hostname("dev-construction.example.org"), "the hostname dev-construction.example.org of the site trislab-website-construction is in no domain")
}

test_zz_3 if {
	denies(with_site_hostname("dev.construction.trislab.com"), "is more than one label below trislab.com")
}

test_zz_4 if {
	denies(with_site_hostname("dev-construction.astra-group.example"), "is in astra-group.example, which belongs to another customer")
}

test_zz_5 if {
	pr := with_site_hostname("dev-construction.example.org")
	some msg in denied(pr)
	contains(msg, "dev-construction.example.org")
}

test_zz_6 if {
	pr := with_site_hostname("dev.construction.trislab.com")
	count([m | some m in denied(pr); contains(m, "label")]) > 0
}

test_zz_7 if {
	pr := with_site_hostname("dev-construction.astra-group.example")
	count([m | some m in denied(pr); contains(m, "another customer")]) > 0
}
