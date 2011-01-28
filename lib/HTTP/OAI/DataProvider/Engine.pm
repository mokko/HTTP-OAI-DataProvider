package HTTP::OAI::DataProvider::Result;


=head2 Engine Requirements

Engine interfaces the data store on the one side and data provider on the side.

What does the engine need?

	my $header=findByIdentifier ($identifier);
	my $date=$engine->earliestDate();
	my $granuality=$engine->granularity();
	my @used_sets=$engine->listSets();

	my $result=$engine->queryHeaders ($params);
	my $result=$engine->queryRecords ($params);

=cut

=head2 my $cache=new HTTP::OAI::DataRepository::Result (
);
=cut


1; #HTTP::OAI::DataProvider::Engine
