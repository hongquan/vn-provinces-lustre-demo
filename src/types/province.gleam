import types/core

pub type Province {
  Province(name: String, code: Int)
}

pub type ComboboxMsg {
  Focus
  ClearClick
  TextInput(String)
  Slide(core.SlideDir)
  Selected(Province)
}
