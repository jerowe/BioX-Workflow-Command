package TestsFor::BioX::Workflow::Command::run::Test012;

use Test::Class::Moose;
use Cwd;
use FindBin qw($Bin);
use File::Path qw(make_path remove_tree);
use Data::Dumper;
use Capture::Tiny ':all';
use BioX::Workflow::Command;
use YAML::XS;
use File::Slurp;
use File::Spec;
use DateTime;
use DateTime::Format::Strptime;
use Storable qw(dclone);
use Text::CSV::Slurp;
use JSON;

extends 'TestMethod::Base';

=head1 Purpose

Ensure directory structure is correct when samples are files and output is
directories

=cut

sub write_test_file {
    my $test_dir = shift;

    my $template = <<EOF;
{{sample}}
{{#some_list}}
List: {{.}}
{{/some_list}}
Basename: {{basename_input}}
EOF
    my $href = {
        global => [
            { sample_rule       => "(Sample_.*)" },
            { root_dir          => 'data/analysis' },
            { root_dir          => 'data/analysis' },
            { indir             => 'data/raw' },
            { outdir            => 'data/processed' },
            { jellyfish_dir     => 'data/analysis/{$sample}/jellyfish' },
            { find_sample_bydir => 0 },
            { by_sample_outdir  => 1 },
            { HPC               => [ { account => 'gencore' } ] },
        ],
        rules => [
            {
                jellyfish => {
                    'local' => [
                        { root_dir           => 'data/raw' },
                        { some_list          => [ 1, 2, 3, 4 ] },
                        { some_glob => 'data/raw/*'},
                        { template_mustache  => $template },
                        { register_namespace => ['Test::Custom::Eval'] },
                        {
                            INPUT => '{$self->jellyfish_dir}/some_input_rule1'
                        },
                        { basename_input => '{ basename($self->INPUT) }'},
                        { OUTPUT => '{$self->jellyfish_dir}/some_input_rule1' },
                        { HPC    => [ { 'deps' => 'some_dep' } ] }
                    ],
                    process =>
'R1: INDIR: {$self->indir} INPUT: {$self->INPUT} outdir: {$self->outdir} OUTPUT: {$self->OUTPUT}',
                },
            },
        ]
    };

    ## Setup the directory structure
    make_path( File::Spec->catdir( $test_dir, 'data', 'raw' ) );
    write_file( File::Spec->catdir( $test_dir, 'data', 'raw', 'Sample_01' ),
        '' );
    write_file( File::Spec->catdir( $test_dir, 'data', 'raw', 'Sample_02' ),
        '' );
    write_file( File::Spec->catdir( $test_dir, 'data', 'raw', 'Sample_03' ),
        '' );
    write_file( File::Spec->catdir( $test_dir, 'data', 'raw', 'NOT_A_SAMPLE' ),
        '' );

    ## Write out the config
    my $file = File::Spec->catdir( $test_dir, 'conf', 'test1.1.yml' );
    my $yaml = Dump $href;
    write_file( $file, $yaml );
}

sub construct_tests {
    my $test_methods = TestMethod::Base->new();
    my $test_dir     = $test_methods->make_test_dir();

    write_test_file($test_dir);

    my $t = File::Spec->catdir( $test_dir, 'conf', 'test1.1.yml' );
    my $test =
      $test_methods->make_test_env( $t, [ '--exclude_samples', 'Sample_03' ] );
    my $rules = $test->workflow_data->{rules};

    return ( $test, $test_dir, $rules );
}

sub test_001 {
    my ( $test, $test_dir, $rules ) = construct_tests;

    $test->set_rule_names;
    $test->filter_rule_keys;

    foreach my $rule ( @{$rules} ) {
        _init_rule( $test, $rule );
    }

    my $attr = dclone($test->local_attr);
    my $text = $test->eval_process($attr);
    $test->post_process_rules;

    is_deeply( $test->exclude_samples, ['Sample_03'] );
    is_deeply( $test->samples, [ 'Sample_01', 'Sample_02' ] );

    ok( ( -d 'data/processed/Sample_01/jellyfish' ) );
    ok( ( -d 'data/processed/Sample_02/jellyfish' ) );

    is( $text, 'HELLO FROM JELLYFISH!' );
}

sub test_002 {
    my ( $test, $test_dir, $rules ) = construct_tests;
    my $rule = $rules->[0];
    _init_rule( $test, $rule );

    # $test->sample('Sample_01');
    my $attr = dclone($test->local_attr);
    $attr->sample('Sample_01');
    $test->sample('Sample_01');
    $test->eval_process($attr);

    my $text = $attr->render_mustache( $attr->template_mustache, 0 );
    my $expect = <<EOF;
Sample_01
List: 1
List: 2
List: 3
List: 4
Basename: some_input_rule1
EOF
    is( $text, $expect, 'Mustache template matches' );
}
#
sub test_003 {
    my ( $test, $test_dir, $rules ) = construct_tests;
    my $rule = $rules->[0];
    _init_rule( $test, $rule );

    my $attr = dclone($test->local_attr);
    $test->eval_process($attr);
    my $json = $attr->serialize_to_json;
    ok(1);
}

sub _init_rule {
    my $test = shift;
    my $rule = shift;

    $test->local_rule($rule);
    $test->process_rule;
    $test->p_rule_name( $test->rule_name );
    $test->p_local_attr( dclone( $test->local_attr ) );
}

1;

package Test::Custom::Eval;

use Moose::Role;
use namespace::autoclean;

sub eval_rule_jellyfish {
    my $self    = shift;
    my $process = shift;

    return 'HELLO FROM JELLYFISH!';
}

1;
