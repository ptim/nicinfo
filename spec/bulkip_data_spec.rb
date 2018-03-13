# Copyright (C) 2018 American Registry for Internet Numbers
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
# IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

require 'time'
require 'ipaddr'
require 'spec_helper'
require 'rspec'
require 'pp'
require_relative '../lib/nicinfo/bulkip_data'
require_relative '../lib/nicinfo/ip'
require_relative '../lib/nicinfo/common_summary'

describe 'bulk_data test' do

  @work_dir = nil

  before( :all ) do

    @work_dir = Dir.mktmpdir

  end

  after( :all ) do

    FileUtils.rm_r( @work_dir )

  end

  it 'should scan population' do

    dir = File.join( @work_dir, "scan_population" )
    logger = NicInfo::Logger.new
    logger.data_out = StringIO.new
    logger.message_out = StringIO.new
    logger.message_level = NicInfo::MessageLevel::NO_MESSAGES
    appctx = NicInfo::AppContext.new(dir )
    appctx.logger=logger
    appctx.config[ NicInfo::BOOTSTRAP ][ NicInfo::UPDATE_BSFILES ]=false

    ip192 = NicInfo::Ip.new( appctx )
    ip192.objectclass = { "handle" => "ip192"}
    ip192.summary_data = Hash.new
    ip192.summary_data[ NicInfo::CommonSummary::CIDRS ] = [ "192.168.0.0/16" ]

    ip10 = NicInfo::Ip.new( appctx )
    ip10.objectclass = { "handle" => "ip10"}
    ip10.summary_data = Hash.new
    ip10.summary_data[ NicInfo::CommonSummary::CIDRS ] = [ "10.0.0.0/8" ]

    b = NicInfo::BulkIPData.new( appctx )
    b.note_new_file
    t = Time.new
    expect( b.query_for_net?(IPAddr.new("192.168.0.1" ), t ) ).to eq( NicInfo::BulkIPData::NetNotFound )
    b.observe_network( ip192, t )
    expect( b.query_for_net?(IPAddr.new("192.0.0.1" ), t ) ).to eq( NicInfo::BulkIPData::NetNotFound )
    expect( b.query_for_net?(IPAddr.new("192.168.0.1" ), t ) ).to eq( NicInfo::BulkIPData::NetAlreadyRetreived )
    t = t + 300
    expect( b.query_for_net?(IPAddr.new("10.0.0.1" ), t ) ).to eq( NicInfo::BulkIPData::NetNotFound )
    b.observe_network( ip10, t )
    expect( b.query_for_net?(IPAddr.new("10.0.0.1" ), t ) ).to eq( NicInfo::BulkIPData::NetAlreadyRetreived )
    expect( b.query_for_net?(IPAddr.new("192.0.0.1" ), t ) ).to eq( NicInfo::BulkIPData::NetNotFound )

  end

  it 'should sample population' do

    dir = File.join( @work_dir, "sample_population" )
    logger = NicInfo::Logger.new
    logger.data_out = StringIO.new
    logger.message_out = StringIO.new
    logger.message_level = NicInfo::MessageLevel::NO_MESSAGES
    appctx = NicInfo::AppContext.new(dir )
    appctx.logger=logger
    appctx.config[ NicInfo::BOOTSTRAP ][ NicInfo::UPDATE_BSFILES ]=false

    ip192 = NicInfo::Ip.new( appctx )
    ip192.objectclass = { "handle" => "ip192"}
    ip192.summary_data = Hash.new
    ip192.summary_data[ NicInfo::CommonSummary::CIDRS ] = [ "192.168.0.0/16" ]

    b = NicInfo::BulkIPData.new( appctx )
    b.set_interval_seconds_to_increment( 100 )
    b.note_new_file
    t = Time.at( 100 )
    expect( b.query_for_net?(IPAddr.new("192.168.0.1" ), t ) ).to eq( NicInfo::BulkIPData::NetNotFound )
    expect( b.second_to_sample.to_i ).to eq( t.to_i )
    b.observe_network( ip192, t )
    t = t + 1
    expect( b.query_for_net?(IPAddr.new("192.0.0.1" ), t ) ).to eq( NicInfo::BulkIPData::NetNotFoundBetweenIntervals )
    expect( b.second_to_sample.to_i ).to be >= (t.to_i )
    expect( b.second_to_sample.to_i ).to be < (t.to_i + 100 )
    expect( b.query_for_net?(IPAddr.new("192.0.0.1" ), Time.at(b.second_to_sample ) ) ).to eq( NicInfo::BulkIPData::NetNotFound )
    expect( b.query_for_net?(IPAddr.new("192.168.0.1" ), Time.at(b.second_to_sample ) ) ).to eq( NicInfo::BulkIPData::NetAlreadyRetreived )
    t = t + 200
    expect( b.query_for_net?(IPAddr.new("192.0.0.1" ), t ) ).to eq( NicInfo::BulkIPData::NetNotFound )
    expect( b.second_to_sample.to_i ).to be >= (t.to_i )
    expect( b.second_to_sample.to_i ).to be < (t.to_i + 100 )

  end

  it 'should do interval calculations' do

    os = NicInfo::BulkIPObservation::OverallStats.new( NicInfo::Stat.new, NicInfo::Stat.new, NicInfo::Stat.new )
    t = Time.at( 100 )
    o = NicInfo::BulkIPObservation.new( t, os )
    expect( o.shortest_interval ).to be_nil
    o.observed( t )
    expect( o.shortest_interval ).to be_nil
    t = t + 1
    o.observed( t )
    expect( o.shortest_interval ).to be_nil
    t = t + 3
    o.observed( t )
    expect( o.shortest_interval ).to eq( 2 )
    t = t + 10
    o.observed( t )
    t = t + 2
    o.observed( t )
    expect( o.shortest_interval ).to eq( 1 )
    expect( o.longest_interval ).to eq( 9 )

    o.finish_calculations
    expect( o.interval_sum ).to eq( 12 )
    expect( o.interval_count ).to eq( 3 )
    expect( o.get_interval_average ).to eq( 4 )
    expect( o.get_interval_standard_deviation( false ) ).to be_within( 0.0001 ).of( 3.5590 )
    expect( o.get_interval_cv( false ) ).to be_within( 0.0001 ).of( 0.8897 )
    expect( os.interval.get_average ).to eq( 4 )
    expect( os.interval.get_std_dev( false ) ).to be_within( 0.0001 ).of( 3.5590 )
    expect( os.interval.get_cv( false ) ).to be_within( 0.0001 ).of( 0.8897 )

  end

  it 'should do interval calculations on no intervals 1 run of 1' do

    os = NicInfo::BulkIPObservation::OverallStats.new( NicInfo::Stat.new, NicInfo::Stat.new, NicInfo::Stat.new )
    t = Time.at( 100 )
    o = NicInfo::BulkIPObservation.new( t, os )
    o.observed( t )

    o.finish_calculations
    expect( o.shortest_interval ).to be_nil
    expect( o.longest_interval ).to be_nil
    expect( o.interval_sum ).to eq( 0 )
    expect( o.interval_count ).to eq( 0 )

  end

  it 'should do interval calculations on no intervals 1 run of 2' do

    os = NicInfo::BulkIPObservation::OverallStats.new( NicInfo::Stat.new, NicInfo::Stat.new, NicInfo::Stat.new )
    t = Time.at( 100 )
    o = NicInfo::BulkIPObservation.new( t, os )
    o.observed( t )
    t = t + 1
    o.observed( t )

    o.finish_calculations
    expect( o.shortest_interval ).to be_nil
    expect( o.longest_interval ).to be_nil
    expect( o.interval_sum ).to eq( 0 )
    expect( o.interval_count ).to eq( 0 )

  end

  it 'should do run calculations' do

    os = NicInfo::BulkIPObservation::OverallStats.new( NicInfo::Stat.new, NicInfo::Stat.new, NicInfo::Stat.new )
    t = Time.at( 100 )
    o = NicInfo::BulkIPObservation.new( t, os )
    o.observed( t )
    t = t + 1
    o.observed( t )
    t = t + 1
    o.observed( t )

    t = t + 5
    o.observed( t )
    t = t + 1
    o.observed( t )
    t = t + 1
    o.observed( t )

    t = t + 10
    o.observed( t )
    t = t + 1
    o.observed( t )

    t = t + 5
    o.observed( t )
    t = t + 1
    o.observed( t )
    t = t + 1
    o.observed( t )
    t = t + 1
    o.observed( t )

    o.finish_calculations
    expect( o.shortest_run ).to eq( 2 )
    expect( o.longest_run ).to eq( 4 )
    expect( o.run_sum ).to eq( 12 )
    expect( o.run_count ).to eq( 4 )
    expect( o.get_run_average ).to eq( 3 )
    expect( o.get_run_standard_deviation( false ) ).to be_within( 0.0001 ).of( 0.7071 )
    expect( o.get_run_cv( false ) ).to be_within( 0.0001 ).of( 0.2357 )
    expect( os.run.get_average ).to eq( 3 )
    expect( os.run.get_std_dev( false ) ).to be_within( 0.0001 ).of( 0.7071 )
    expect( os.run.get_cv( false ) ).to be_within( 0.0001 ).of( 0.2357 )

  end

  it 'should do run calculations on 1 run of 1' do

    os = NicInfo::BulkIPObservation::OverallStats.new( NicInfo::Stat.new, NicInfo::Stat.new, NicInfo::Stat.new )
    t = Time.at( 100 )
    o = NicInfo::BulkIPObservation.new( t, os )
    o.observed( t )

    o.finish_calculations
    expect( o.shortest_run ).to eq( 1 )
    expect( o.longest_run ).to eq( 1 )
    expect( o.run_sum ).to eq( 1 )
    expect( o.run_count ).to eq( 1 )

  end

  it 'should do run calculations on 1 run of 2' do

    os = NicInfo::BulkIPObservation::OverallStats.new( NicInfo::Stat.new, NicInfo::Stat.new, NicInfo::Stat.new )
    t = Time.at( 100 )
    o = NicInfo::BulkIPObservation.new( t, os )
    o.observed( t )
    t = t + 1
    o.observed( t )

    o.finish_calculations
    expect( o.shortest_run ).to eq( 2 )
    expect( o.longest_run ).to eq( 2 )
    expect( o.run_sum ).to eq( 2 )
    expect( o.run_count ).to eq( 1 )

  end

  it 'should do magnitude calculations' do

    os = NicInfo::BulkIPObservation::OverallStats.new( NicInfo::Stat.new, NicInfo::Stat.new, NicInfo::Stat.new )
    t = Time.at( 100 )
    o = NicInfo::BulkIPObservation.new( t, os )
    expect( o.magnitude_ceiling ).to eq(1 )
    o.observed( t )
    expect( o.magnitude_ceiling ).to eq(2 )
    o.observed( t )
    expect( o.magnitude_ceiling ).to eq(3 )

    t2 = Time.at( 200 )
    o.observed( t2 )
    expect( o.magnitude_ceiling ).to eq(3 )
    o.observed( t2 )
    expect( o.magnitude_ceiling ).to eq(3 )
    o.observed( t2 )
    expect( o.magnitude_ceiling ).to eq(3 )
    o.observed( t2 )
    expect( o.magnitude_ceiling ).to eq(4 )
    o.observed( t2 )
    expect( o.magnitude_ceiling ).to eq(5 )

    t3 = Time.at( 300 )
    o.observed( t3 )
    o.observed( t3 )
    o.observed( t3 )
    o.observed( t3 )

    o.finish_calculations
    expect( o.magnitude_floor ).to eq(3 )
    expect( o.magnitude_ceiling ).to eq(5 )
    expect( o.magnitude_sum ).to eq( 12 )
    expect( o.magnitude_count ).to eq( 3 )
    expect( o.get_magnitude_average ).to eq( 4 )
    expect( o.get_magnitude_standard_deviation( false ) ).to be_within(0.0001).of( 0.8164 )
    expect( o.get_magnitude_cv( false ) ).to be_within( 0.0001 ).of( 0.2041 )
    expect( os.magnitude.get_average ).to eq( 4 )
    expect( os.magnitude.get_std_dev( false ) ).to be_within(0.0001).of( 0.8164 )
    expect( os.magnitude.get_cv( false ) ).to be_within( 0.0001 ).of( 0.2041 )

  end

end
