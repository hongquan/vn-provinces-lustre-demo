import mytype/core

pub type Ward {
  Ward(name: String, code: Int, province_code: Int)
}

// Legacy (pre-2025) ward
pub type SourceWard {
  SourceWard(name: String, code: Int, district_code: Int, province_code: Int)
}

pub type ComboboxMsg {
  Focus
  ClearClick
  TextInput(String)
  Slide(core.SlideDir)
  Selected(Ward)
}
