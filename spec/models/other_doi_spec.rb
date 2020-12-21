# frozen_string_literal: true

require "rails_helper"

describe OtherDoi, type: :model do
  it_behaves_like "an STI class"

  describe "import_by_ids", elasticsearch: true do
    let!(:dois) do
      create_list(:doi, 3, aasm_state: "findable", type: "OtherDoi")
    end
    let(:doi) { dois.first }

    it "import by ids" do
      response = Doi.import_by_ids(model: "OtherDoi")
      expect(response).to be > 0
    end

    it "import by id" do
      response = Doi.import_by_id(model: "OtherDoi", id: doi.id)
      sleep 3
      expect(response).to eq(3)
    end
  end
end
