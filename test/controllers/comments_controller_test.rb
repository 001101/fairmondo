#
#
# == License:
# Fairmondo - Fairmondo is an open-source online marketplace.
# Copyright (C) 2013 Fairmondo eG
#
# This file is part of Fairmondo.
#
# Fairmondo is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# Fairmondo is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Fairmondo. If not, see <http://www.gnu.org/licenses/>.
#
#
require_relative "../test_helper"

describe CommentsController do
  describe "GET comments on library" do
    before :each do
      @library = FactoryGirl.create(:library, public: true)
      @user = FactoryGirl.create(:user)
      @comment = FactoryGirl.create(:comment,
                                    text: "Test comment",
                                    commentable: @library,
                                    user: @user)
    end

    it "should return the comments of the library for guests" do
      xhr(:get, :index, library_id: @library.id,
                        comments_page: 1)

      assert_response :success
    end

    it "should return the comments of the library for logged in users" do
      sign_in @user
      xhr(:get, :index, library_id: @library.id,
                        comments_page: 1)

      assert_response :success
    end

    it "should render the paginated partial if the page param is there" do
      xhr(:get, :index, library_id: @library.id,
                        comments_page: 1)

      assert_template "comments/_index_paginated"
    end
  end

  describe "POST comment on library" do
    before :each do
      @library = FactoryGirl.create(:library)
      @user = FactoryGirl.create(:user)
      sign_in @user
    end

    describe "with valid params" do
      it "should allow posting using ajax" do
        xhr(:post, :create, comment: { text: "test" },
                            library_id: @library.id)

        assert_response :success
        assert_nil(assigns(:message))
      end

      it "increases the counter cache" do
        assert_difference "@library.comments_count", 1 do
          xhr(:post, :create, comment: { text: "test" },
                              library_id: @library.id)

          @library.reload
        end
      end
    end

    describe "with invalid params" do
      it "does not increase the comment count" do
        assert_difference "@library.comments.count", 0 do
          post :create, comment: { text: "" },
                        library_id: @library.id + 1,
                        format: :js
        end
      end

      it "renders the new template" do
        post :create, comment: { text: "" },
                      library_id: @library.id + 1,
                      format: :js
        assert_template "new"
      end
    end
  end

  describe "DELETE comment on library" do
    before :each do
      @library = FactoryGirl.create(:library)
      @user = FactoryGirl.create(:user)
      sign_in @user
      @comment = FactoryGirl.create(:comment,
                                    text: "Test comment",
                                    commentable: @library,
                                    user: @user)
    end

    it "it should remove the comment" do
      delete :destroy, id: @comment.id,
                       library_id: @library.id,
                       format: :js

      assert_response :success
    end
  end
end
