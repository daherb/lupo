require 'rails_helper'

RSpec.describe DatacentersController, type: :controller do

  let(:valid_attributes) {
    skip("Add a hash of attributes valid for your model")
  }

  let(:invalid_attributes) {
    skip("Add a hash of attributes invalid for your model")
  }

  let(:valid_session) { {} }

  describe "GET #index" do
    it "returns a success response" do
      datacenter = Datacenter.create! valid_attributes
      get :index, params: {}, session: valid_session
      expect(response).to be_success
    end
  end

  describe "GET #show" do
    it "returns a success response" do
      datacenter = Datacenter.create! valid_attributes
      get :show, params: {id: datacenter.to_param}, session: valid_session
      expect(response).to be_success
    end
  end

  describe "POST #create" do
    context "with valid params" do
      it "creates a new Datacenter" do
        expect {
          post :create, params: {datacenter: valid_attributes}, session: valid_session
        }.to change(Datacenter, :count).by(1)
      end

      it "renders a JSON response with the new datacenter" do

        post :create, params: {datacenter: valid_attributes}, session: valid_session
        expect(response).to have_http_status(:created)
        expect(response.content_type).to eq('application/json')
        expect(response.location).to eq(datacenter_url(Datacenter.last))
      end
    end

    context "with invalid params" do
      it "renders a JSON response with errors for the new datacenter" do

        post :create, params: {datacenter: invalid_attributes}, session: valid_session
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to eq('application/json')
      end
    end
  end

  describe "PUT #update" do
    context "with valid params" do
      let(:new_attributes) {
        skip("Add a hash of attributes valid for your model")
      }

      it "updates the requested datacenter" do
        datacenter = Datacenter.create! valid_attributes
        put :update, params: {id: datacenter.to_param, datacenter: new_attributes}, session: valid_session
        datacenter.reload
        skip("Add assertions for updated state")
      end

      it "renders a JSON response with the datacenter" do
        datacenter = Datacenter.create! valid_attributes

        put :update, params: {id: datacenter.to_param, datacenter: valid_attributes}, session: valid_session
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/json')
      end
    end

    context "with invalid params" do
      it "renders a JSON response with errors for the datacenter" do
        datacenter = Datacenter.create! valid_attributes

        put :update, params: {id: datacenter.to_param, datacenter: invalid_attributes}, session: valid_session
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to eq('application/json')
      end
    end
  end

  describe "DELETE #destroy" do
    it "destroys the requested datacenter" do
      datacenter = Datacenter.create! valid_attributes
      expect {
        delete :destroy, params: {id: datacenter.to_param}, session: valid_session
      }.to change(Datacenter, :count).by(-1)
    end
  end

end
