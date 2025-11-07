module cla32(
	input  [31:0] num1, num2,
	input         cin,
	output [31:0] sum,
	output        cout
);
	wire pgroup0, ggroup0;
	wire pgroup1, ggroup1;
	wire pgroup2, ggroup2;
	wire pgroup3, ggroup3;

	wire carry8, carry16, carry24;
    wire t10, t20, t21;
    wire t30, t31, t32;
    wire t40, t41, t42, t43;

	cla8 cla0 (
		.num1(num1[7:0]), .num2(num2[7:0]), .cin(cin),
		.sum(sum[7:0]), .pgroup(pgroup0), .ggroup(ggroup0), .cout()
	);

    and (t10,  pgroup0, cin);
	or  (carry8, ggroup0, t10);

	cla8 cla1 (
		.num1(num1[15:8]), .num2(num2[15:8]), .cin(carry8),
		.sum(sum[15:8]), .pgroup(pgroup1), .ggroup(ggroup1), .cout()
	);

    and (t20, pgroup1, pgroup0, cin);
    and (t21, pgroup1, ggroup0);
	or  (carry16, ggroup1, t20, t21);

	cla8 cla2 (
		.num1(num1[23:16]), .num2(num2[23:16]), .cin(carry16),
		.sum(sum[23:16]), .pgroup(pgroup2), .ggroup(ggroup2), .cout()
	);

    and (t30, pgroup2, pgroup1, pgroup0, cin);
	and (t31, pgroup2, pgroup1, ggroup0);
    and (t32, pgroup2, ggroup1);
	or  (carry24, ggroup2, t30, t31, t32);

	cla8 cla3 (
		.num1(num1[31:24]), .num2(num2[31:24]), .cin(carry24),
		.sum(sum[31:24]), .pgroup(pgroup3), .ggroup(ggroup3), .cout()
	);

	and (t40, pgroup3, pgroup2, pgroup1, pgroup0, cin);
    and (t41, pgroup3, pgroup2, pgroup1, ggroup0);
    and (t42, pgroup3, pgroup2, ggroup1);
    and (t43, pgroup3, ggroup2);
	or  (cout, ggroup3, t40, t41, t42, t43);
endmodule

module cla8(
	input  [7:0] num1, num2,
	input        cin,
	output [7:0] sum,
	output       pgroup, ggroup,
	output       cout
);
    // 1. Compute the propagates and generates
	wire [3:0] prop0, gen0, prop1, gen1;
	wire       pgroup0, ggroup0, pgroup1, ggroup1;
	
	pg4 u_pg0(
		.num1(num1[3:0]), .num2(num2[3:0]),
		.prop(prop0), .gen(gen0), .pgroup(pgroup0), .ggroup(ggroup0)
	);
	pg4 u_pg1(
		.num1(num1[7:4]), .num2(num2[7:4]),
		.prop(prop1), .gen(gen1), .pgroup(pgroup1), .ggroup(ggroup1)
	);

	// 2. Compute lookahead carries
	wire t00, t10, t11, t20;
    wire carry4;

	and (t00, pgroup0, cin);
	or  (carry4, ggroup0, t00);

	and (t10, pgroup1, pgroup0, cin);
	and (t11, pgroup1, ggroup0);
	or  (cout, ggroup1, t10, t11);

	// 3. Compute the sum
	cla_sum4 u_sum0(.prop(prop0), .gen(gen0), .cin(cin), .sum(sum[3:0]), .cout());
	cla_sum4 u_sum1(.prop(prop1), .gen(gen1), .cin(carry4),  .sum(sum[7:4]), .cout());

	and (pgroup, pgroup1, pgroup0);
	and (t20, pgroup1, ggroup0);
	or  (ggroup, ggroup1, t20);
endmodule

module cla_sum4(
	input  [3:0] prop, gen,
	input        cin,
	output [3:0] sum,
	output       cout
);
	wire [4:0] carry;
	wire       t10, t20, t21;
	wire       t30, t31, t32;
	wire       t40, t41, t42, t43;

	// carry 1
	and (t10, prop[0], cin);
	or  (carry[1], gen[0], t10);

	// carry 2
	and (t20, prop[1], prop[0], carry[0]);
	and (t21, prop[1], gen[0]);
	or  (carry[2], gen[1], t20, t21);

	// carry 3
	and (t30, prop[2], prop[1], prop[0], cin);
	and (t31, prop[2], prop[1], gen[0]);
	and (t32, prop[2], gen[1]);
	or  (carry[3], gen[2], t30, t31, t32);

	// carry 4 (cout)
	and (t40, prop[3], prop[2], prop[1], prop[0], cin);
	and (t41, prop[3], prop[2], prop[1], gen[0]);
	and (t42, prop[3], prop[2], gen[1]);
	and (t43, prop[3], gen[2]);
	or  (cout, gen[3], t40, t41, t42, t43);

	assign carry[0] = cin;
    genvar i;

	generate 
        for (i = 0; i < 4; i = i + 1) begin: comp_sum
            xor (sum[i], prop[i], carry[i]);
        end
    endgenerate
endmodule

module pg4(
	input  [3:0] num1, num2,
	output [3:0] prop, gen,
	output       pgroup, ggroup
);

	wire gg0, gg1, gg2;
	genvar i;

	generate
		for (i = 0; i < 4; i = i + 1) begin: comp_pg
			xor (prop[i], num1[i], num2[i]);
			and (gen[i], num1[i], num2[i]);
		end
  	endgenerate

	// pgroup = p3p2p1p0
	and (pgroup,  prop[3], prop[2], prop[1], prop[0]);

	// ggroup = g3 | p3g2 | p3p2g1 | p3p2p1g0
	and (gg0, prop[3], prop[2], prop[1], gen[0]);
	and (gg1, prop[3], prop[2], gen[1]);
	and (gg2, prop[3], gen[2]);
	or  (ggroup, gen[3], gg0, gg1, gg2);
endmodule
