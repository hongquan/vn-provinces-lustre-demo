import gleam/int
import gleam/option.{None, Some}
import gleam/string
import gleam/uri
import iv
import lustre/effect.{type Effect}
import modem
import types/ward

import actions
import common.{type Model, type Msg, Model}
import router
import types/core.{ComboboxState}
import types/core.{SlideUp} as _core
import types/province
import views.{scroll_to_see_focused_item}

pub fn handle_province_combobox(
  msg: province.ComboboxMsg,
  model: Model,
  element_id: String,
) -> #(Model, Effect(Msg)) {
  case msg {
    province.Focus -> {
      let model =
        Model(
          ..model,
          province_combobox_state: ComboboxState(
            ..model.province_combobox_state,
            is_shown: True,
          ),
        )
      #(model, effect.none())
    }
    province.ClearClick -> {
      #(model, modem.push(".", Some(""), None))
    }
    province.Selected(p) -> {
      let model =
        Model(
          ..model,
          province_combobox_state: ComboboxState(
            ..model.province_combobox_state,
            selected_item: Some(p),
            filter_text: p.name,
            is_shown: False,
          ),
        )
      // Reflect to browser URL
      let query_string = uri.query_to_string([#("p", int.to_string(p.code))])
      #(model, modem.push("", Some(query_string), None))
    }
    province.TextInput(s) -> {
      let provinces = model.provinces
      let filtered_provinces = model.province_combobox_state.filtered_items
      // If the text input contains empty string,
      // we show all provinces in the dropdown.
      let #(filtered_provinces, what_next) = case string.trim(s) {
        "" -> #(iv.from_list(provinces), effect.none())
        q -> #(filtered_provinces, actions.search_provinces(q))
      }
      let model =
        Model(
          ..model,
          province_combobox_state: ComboboxState(
            ..model.province_combobox_state,
            filter_text: s,
            filtered_items: filtered_provinces,
          ),
        )
      #(model, what_next)
    }
    province.Slide(dir) -> {
      let filtered_provinces = model.province_combobox_state.filtered_items
      let focused_index = model.province_combobox_state.focused_index
      let i = case dir {
        // The lower item has higher index, so pressing ↑ means to go to lower index. 
        SlideUp -> focused_index - 1
        _ -> focused_index + 1
      }
      let focused_index = int.clamp(i, 0, iv.size(filtered_provinces))
      let model =
        Model(
          ..model,
          province_combobox_state: ComboboxState(
            ..model.province_combobox_state,
            focused_index:,
          ),
        )
      #(model, scroll_to_see_focused_item(element_id, focused_index))
    }
  }
}

pub fn handle_ward_combobox(
  msg: ward.ComboboxMsg,
  model: Model,
  element_id: String,
) -> #(Model, Effect(Msg)) {
  case msg {
    ward.Focus -> {
      let model =
        Model(
          ..model,
          ward_combobox_state: ComboboxState(
            ..model.ward_combobox_state,
            is_shown: True,
          ),
        )
      #(model, effect.none())
    }
    ward.ClearClick -> {
      let q =
        model.province_combobox_state.selected_item
        |> option.map(fn(p) {
          uri.query_to_string([#("p", int.to_string(p.code))])
        })
      #(model, modem.push(".", q, None))
    }
    ward.TextInput(s) -> {
      let wards = model.wards
      let selected_province = model.province_combobox_state.selected_item
      let filtered_wards = model.ward_combobox_state.filtered_items
      // If the text input contains empty string,
      // we show all wards in the dropdown.
      let #(filtered_wards, what_next) = case string.trim(s) {
        "" -> #(iv.from_list(wards), effect.none())
        q -> {
          let province_code =
            selected_province
            |> option.map(fn(p) { p.code })
            |> option.unwrap(0)
          #(filtered_wards, actions.search_wards(q, province_code))
        }
      }
      let model =
        Model(
          ..model,
          ward_combobox_state: ComboboxState(
            ..model.ward_combobox_state,
            filter_text: s,
            filtered_items: filtered_wards,
          ),
        )
      #(model, what_next)
    }
    ward.Slide(dir) -> {
      let focused_index = model.ward_combobox_state.focused_index
      let filtered_wards = model.ward_combobox_state.filtered_items
      let i = case dir {
        // The lower item has higher index, so pressing ↑ means to go to lower index. 
        SlideUp -> focused_index - 1
        _ -> focused_index + 1
      }
      let focused_index = int.clamp(i, 0, iv.size(filtered_wards))
      // The focused ward may be not visible due to scrolled container,
      // we will create an effect to tell browser to scroll the ward into view.
      let model =
        Model(
          ..model,
          ward_combobox_state: ComboboxState(
            ..model.ward_combobox_state,
            focused_index:,
          ),
        )
      #(model, scroll_to_see_focused_item(element_id, focused_index))
    }
    ward.Selected(w) -> {
      let model =
        Model(
          ..model,
          ward_combobox_state: ComboboxState(
            ..model.ward_combobox_state,
            is_shown: False,
            filter_text: w.name,
            selected_item: Some(w),
          ),
        )
      // Reflect to browser URL
      let new_append = #("w", int.to_string(w.code))
      let new_query = case model.route {
        router.Province(p, _w) -> [#("p", int.to_string(p)), new_append]
        _ -> [new_append]
      }
      #(model, modem.push("", Some(uri.query_to_string(new_query)), None))
    }
  }
}
