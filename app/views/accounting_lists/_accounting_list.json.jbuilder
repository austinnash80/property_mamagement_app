json.extract! accounting_list, :id, :accounting_type, :vendor, :amount, :notes, :created_at, :updated_at
json.url accounting_list_url(accounting_list, format: :json)
