import types/core

pub type Ward {
  Ward(name: String, code: Int, province_code: Int)
}

pub type ComboboxMsg {
  Focus
  ClearClick
  TextInput(String)
  Slide(core.SlideDir)
  Selected(Ward)
}
