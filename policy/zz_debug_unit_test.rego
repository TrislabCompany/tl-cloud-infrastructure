package catalog

test_zz_debug if {
	every h in ["prod-corporate-site.trislab.com", "dev-construction.example.org", "dev.construction.trislab.com", "dev-construction.astra-group.example"] {
		print("HOST", h, [m | some m in denied(with_site_hostname(h))])
	}
}
