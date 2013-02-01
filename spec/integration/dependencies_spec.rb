require 'spec_helper'

describe Promiscuous do
  before { load_models }
  before { use_real_amqp }

  before do
    define_constant('Publisher', ORM::PublisherBase) do
      publish :to => 'crowdtap/publisher_model',
              :class => :PublisherModel,
              :attributes => [:field_1, :field_2, :field_3]
    end

    define_constant('Subscriber', ORM::SubscriberBase) do
      subscribe :from => 'crowdtap/publisher_model',
                :class => :SubscriberModel,
                :attributes => [:field_1, :field_2, :field_3]
    end
  end

  before { record_callbacks(SubscriberModel) }

  before { Promiscuous::Worker.replicate }

  context 'with total ordering' do
    context 'when the messages arrive out of order' do
      it 'replicates' do
        Publisher.any_instance.stubs(:version).returns(
          {:global => 1}, {:global => 3}, {:global => 2}
        )

        pub = PublisherModel.create(:field_1 => '1')
        pub.update_attributes(:field_1 => '2')
        pub.update_attributes(:field_1 => '3')

        eventually do
          SubscriberModel.first.field_1.should == '2'
          SubscriberModel.num_saves.should == 3
        end
      end
    end

    context 'when the publisher fails' do
      it 'replicates' do
        pub1 = PublisherModel.create(:field_1 => '1')
        expect do
          PublisherModel.create({:id => pub1.id, :field_1 => '2'}, :without_protection => true)
        end.to raise_error
        pub3 = PublisherModel.create(:field_1 => '3')

        eventually do
          SubscriberModel.where(:id => pub1.id).first.should_not == nil
          SubscriberModel.where(:id => pub3.id).first.should_not == nil
        end
      end
    end

  end
end