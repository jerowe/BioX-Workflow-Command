package BioX::Workflow::Command::new;

use v5.10;
use MooseX::App::Command;
use namespace::autoclean;

use Storable qw(dclone);
use YAML;

use MooseX::Types::Path::Tiny qw/Path/;

use BioSAILs::Utils::Traits qw(ArrayRefOfStrs);

extends 'BioX::Workflow::Command';

with 'BioX::Workflow::Command::Utils::Create';
with 'BioX::Workflow::Command::Utils::Files';

command_short_description 'Create a new workflow.';
command_long_description 'Create a new workflow.';

=head1 BioX::Workflow::Command::new

Create a new workflow

  biox new -h
  biox new -w my_new_workflow.yml

=cut

=head2 Command Line Options

=cut

option '+workflow' => (
    isa           => Path,
);

option '+outfile' => (
    default => sub {
        my $self = shift;
        my $workflow = $self->workflow;
        return "$workflow";
    },
);

sub execute {
    my $self = shift;

    my $global = {
        global =>
            [
                { sample_rule      => "(Sample_.*)" },
                { indir            => 'data/raw' },
                { outdir           => 'data/processed' },
                { root_dir         => 'data' },
                { find_sample_bydir     => 1 },
                { by_sample_outdir => 1 },
            ]
    };

    my $rules  = $self->add_rules;
    $global->{rules} = $rules;

    $self->fh->print(Dump($global));
    $self->fh->close;
}

__PACKAGE__->meta->make_immutable;

1;
