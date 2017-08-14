require 'rails_helper'

RSpec.describe MembersController, type: :controller do

  # This should return the minimal set of attributes required to create a valid
  # Member. As you add validations to Member, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) {
    skip("Add a hash of attributes valid for your model")
  }

  let(:invalid_attributes) {
    skip("Add a hash of attributes invalid for your model")
  }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # MembersController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe "GET #index" do
    it "returns a success response" do
      member = Member.create! valid_attributes
      get :index, params: {}, session: valid_session
      expect(response).to be_success
    end
  end

  describe "GET #show" do
    it "returns a success response" do
      member = Member.create! valid_attributes
      get :show, params: { id: member.to_param }, session: valid_session
      expect(response).to be_success
    end
  end

  describe "POST #create" do
    context "with valid params" do
      it "creates a new Member" do
        expect {
          post :create, params: { member: valid_attributes }, session: valid_session
        }.to change(Member, :count).by(1)
      end

      it "renders a JSON response with the new Member" do

        post :create, params: { member: valid_attributes }, session: valid_session
        expect(response).to have_http_status(:created)
        expect(response.content_type).to eq('application/json')
        expect(response.location).to eq(member_url(Member.last))
      end
    end

    context "with invalid params" do
      it "renders a JSON response with errors for the new Member" do

        post :create, params: {Member: invalid_attributes}, session: valid_session
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

      it "updates the requested Member" do
        member = Member.create! valid_attributes
        put :update, params: {id: member.to_param, Member: new_attributes}, session: valid_session
        member.reload
        skip("Add assertions for updated state")
      end

      it "renders a JSON response with the Member" do
        member = Member.create! valid_attributes

        put :update, params: {id: member.to_param, Member: valid_attributes}, session: valid_session
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/json')
      end
    end

    context "with invalid params" do
      it "renders a JSON response with errors for the Member" do
        member = Member.create! valid_attributes

        put :update, params: {id: member.to_param, Member: invalid_attributes}, session: valid_session
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to eq('application/json')
      end
    end
  end

  describe "DELETE #destroy" do
    it "destroys the requested Member" do
      member = Member.create! valid_attributes
      expect {
        delete :destroy, params: {id: member.to_param}, session: valid_session
      }.to change(Member, :count).by(-1)
    end
  end

end
