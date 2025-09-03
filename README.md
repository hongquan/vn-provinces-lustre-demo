# VN Provinces API Demo

A pure frontend website to lookup Viet Nam administrative divisions.

[Live demo](https://vn-provinces-lustre-demo.netlify.app/)

Written in [Gleam](https://gleam.run/) language ([Lustre](https://hexdocs.pm/lustre/) framework), it demonstrates how to use API from https://provinces.open-api.vn/.

As a reference for Gleam & Lustre fellows, this application is using these techniques:

- Implementing combobox widget from scratch.
- Routing (with [modem](https://hexdocs.pm/modem/)). It is to save the data selection to the URL, so that the selection won't be lost when refreshing page, or when copying and sharing URL to someone else.
- Implement "click outside" to close dropdown menu.
- Unpack assignment with nested records.
