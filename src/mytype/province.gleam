import mytype/core

pub type Province {
  Province(name: String, code: Int)
}

// Legacy (pre-2025) province
pub type LeProvince {
  LeProvince(name: String, code: Int)
}

// Legacy (pre-2025) district
pub type LeDistrict {
  LeDistrict(name: String, code: Int, province_code: Int)
}

pub type ComboboxMsg {
  Focus
  ClearClick
  TextInput(String)
  Slide(core.SlideDir)
  Selected(Province)
}
