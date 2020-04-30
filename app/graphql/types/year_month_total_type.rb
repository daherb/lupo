# frozen_string_literal: true

class YearMonthTotalType < BaseObject
  description "Information about totals over time (years)"

  field :year_month, Int, null: true, description: "Year-month"
  field :total, Int, null: true, description: "Total"
end
