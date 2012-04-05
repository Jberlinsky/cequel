require File.expand_path('../spec_helper', __FILE__)

describe Cequel::Model::Persistence do
  describe '#find' do
    it 'should return hydrated instance' do
      connection.stub(:execute).
        with("SELECT * FROM posts WHERE id = 2 LIMIT 1").
        and_return result_stub(:id => 2, :title => 'Cequel')

      post = Post.find(2)
      post.id.should == 2
      post.title.should == 'Cequel'
    end

    it 'should return multiple instances' do
      connection.stub(:execute).
        with("SELECT * FROM posts WHERE id IN (2, 5)").
        and_return result_stub(
          {:id => 2, :title => 'Cequel 2'},
          {:id => 5, :title => 'Cequel 5'}
        )

      posts = Post.find(2, 5)
      posts.map { |post| [post.id, post.title] }.
        should == [[2, 'Cequel 2'], [5, 'Cequel 5']]
    end

    it 'should return one-element array if passed one-element array' do
      connection.stub(:execute).
        with("SELECT * FROM posts WHERE id = 2 LIMIT 1").
        and_return result_stub(:id => 2, :title => 'Cequel')

      post = Post.find([2]).first
      post.id.should == 2
      post.title.should == 'Cequel'
    end

    it 'should raise RecordNotFound if row has no data' do
      connection.stub(:execute).
        with("SELECT * FROM posts WHERE id = 2 LIMIT 1").
        and_return result_stub(:id => 2)

      expect { Post.find(2) }.to raise_error Cequel::Model::RecordNotFound
    end

    it 'should raise RecordNotFound if some rows in multi-row query have no data' do
      connection.stub(:execute).
        with("SELECT * FROM posts WHERE id IN (2, 5)").
        and_return result_stub(
          {:id => 2, :title => 'Cequel 2'},
          {:id => 5}
        )

      expect { Post.find(2, 5) }.to raise_error(Cequel::Model::RecordNotFound)
    end
  end
end