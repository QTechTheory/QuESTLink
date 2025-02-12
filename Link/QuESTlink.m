
(* @file
 * The front-end Mathematica interface between the user API and the backend C++ facilities.
 * Some functions herein merely wrap a core QuEST function, while others require 
 * complicated argument translation, and some invoke only Mathematica routines.
 * The C++ functions are wrapped to become callable Mathematica symbols via templates.tm
 *
 * @author Tyson Jones
 *)

BeginPackage["QuEST`"]    
    
    (* 
     * Note additional functions and their usage messages are fetched when CreateRemoteQuESTEnv is called.
     * The additional functions are provided through WSTP and use the QuEST` prefix to share namespace with this package.
     * This includes QuEST`Private` functions which are thus only called from within this package, which does not need to
     * explicitly use that package. 
     * Note also that public WSTP functions e.g. CloneQureg called from this package must be prefixed here with QuEST` so
     * that they are not incorrectly automatically given a QuEST`Private` prefix. This often will not trigger an error 
     * but will cause incorrect behaviour. When in doubt, give the full explicit name e.g. QuEST`CloneQureg or
     * QuEST`Private`ApplyCircuitInternal. 
     *)


    (*
     * launch notice
     *)

    (* disable QuESTlink from appearing in context symbol list *)
    Begin["`Private`"]
    QuESTlink::notice = "`1`"

    (* prevent message truncation **)
    initPrePrintVal = $MessagePrePrint;
    Unset[$MessagePrePrint];

    (* display launch message *)
    Message[QuESTlink::notice, 
        "Bug alert! Prior to this version (v0.19), SimplifyPaulis[] contained a bug whereby multiplying X and Z operators (targeting the same qubit) produced a Y operator with an incorrect sign. " <>
        "This bug occurred only when multiplying Pauli strings together, and did not affect other algebraic forms (like summing or exponentiation), though did affect the downstream function CalcPauliExpressionMatrix[]. " <>
        "Please check any previous calculations which passed products of Pauli-strings to SimplifyPaulis[] and CalcPauliExpressionMatrix[]. " <>
        "We sincerely apologise for any arising issues! Silence this warning using Quiet[]."];

    (* restore subsequent message truncation (as per user settings) *)
    $MessagePrePrint = initPrePrintVal;

    End[ ]

     
     (*
      * public API 
      *)
    
    ApplyCircuit::usage = "ApplyCircuit[qureg, circuit] modifies qureg by applying the circuit. Returns any measurement outcomes and the probabilities encountered by projectors, ordered and grouped by the appearance of M and P in the circuit.
ApplyCircuit[inQureg, circuit, outQureg] leaves inQureg unchanged, but modifies outQureg to be the result of applying the circuit to inQureg.
Accepts optional arguments WithBackup and ShowProgress."
    ApplyCircuit::error = "`1`"
    
    ApplyCircuitDerivs::usage = "ApplyCircuitDerivs[inQureg, circuit, varVals, outQuregs] modifies outQuregs to be the result of applying the derivatives (with respect to variables in varVals) of the given symbolic circuit to inQureg (which remains unmodified).
    \[Bullet] varVals is a list {symbol -> value, ...} of all variables present in the circuit parameters.
    \[Bullet] outQuregs is a list of quregs to set to the respective derivative of circuit upon inQureg, according to the order of vars.
    \[Bullet] Variable repetition, multi-parameter gates, variable-dependent element-wise matrices, variable-dependent channels, and operators whose parameters are (numerically evaluable) functions of variables are all permitted within the circuit. In effect, every continuously-parameterised circuit or channel is permitted.
ApplyCircuitDerivs[inQureg, circuit, varVals, outQuregs, workQuregs] use the given persistent workspace quregs to avoid tediously creating and destroying any internal quregs, for a speedup. For convenience, any number of workspaces can be passed, but only the first is needed and used."
    ApplyCircuitDerivs::error = "`1`"
    
    CalcExpecPauliStringDerivs::usage = "CalcExpecPauliStringDerivs[inQureg, circuit, varVals, pauliString] returns the gradient vector of the pauliString expected values, as produced by the derivatives of the circuit (with respect to varVals, {var -> value}) acting upon the given initial state (inQureg).
CalcExpecPauliStringDerivs[inQureg, circuit, varVals, pauliQureg] accepts a Qureg pre-initialised as a pauli string via SetQuregToPauliString[] to speedup density-matrix simulation.
CalcExpecPauliStringDerivs[inQureg, circuit, varVals, pauliStringOrQureg, workQuregs] uses the given persistent workspaces (workQuregs) in lieu of creating them internally, and should be used for optimum performance. At most four workQuregs are needed.
    \[Bullet] Variable repetition, multi-parameter gates, variable-dependent element-wise matrices, variable-dependent channels, and operators whose parameters are (numerically evaluable) functions of variables are all permitted. 
    \[Bullet] All operators must be invertible, trace-preserving and deterministic, else an error is thrown. 
    \[Bullet] This function runs asymptotically faster than ApplyCircuitDerivs[] and requires only a fixed memory overhead."
    CalcExpecPauliStringDerivs::error = "`1`"
    
    CalcMetricTensor::usage = "CalcMetricTensor[inQureg, circuit, varVals] returns the natural gradient metric tensor, capturing the circuit derivatives (produced from initial state inQureg) with respect to varVals, specified with values {var -> value, ...}.
    CalcMetricTensor[inQureg, circuit, varVals, workQuregs] uses the given persistent workspace quregs (workQuregs) in lieu of creating them internally, and should be used for optimum performance. At most four workQuregs are needed.
    \[Bullet] For state-vectors and pure circuits, this returns the quantum geometric tensor, which relates to the Fubini-Study metric, the classical Fisher information matrix, and the variational imaginary-time Li tensor with Berry connections.
    \[Bullet] For density-matrices and noisy channels, this function returns the Hilbert-Schmidt derivative metric, which well approximates the quantum Fisher information matrix, though is a more experimentally relevant minimisation metric (https://arxiv.org/abs/1912.08660).
    \[Bullet] Variable repetition, multi-parameter gates, variable-dependent element-wise matrices, variable-dependent channels, and operators whose parameters are (numerically evaluable) functions of variables are all permitted. 
    \[Bullet] All operators must be invertible, trace-preserving and deterministic, else an error is thrown. 
    \[Bullet] This function runs asymptotically faster than ApplyCircuitDerivs[] and requires only a fixed memory overhead."
    CalcMetricTensor::error = "`1`"
    
    CalcInnerProducts::usage = "CalcInnerProducts[quregIds] returns a Hermitian matrix with i-th j-th element CalcInnerProduct[quregIds[i], quregIds[j]].
CalcInnerProducts[braId, ketIds] returns a complex vector with i-th element CalcInnerProduct[braId, ketIds[i]]."
    CalcInnerProducts::error = "`1`"

    CalcDensityInnerProducts::usage = "CalcDensityInnerProducts[quregIds] returns a Hermitian matrix with i-th j-th element CalcDensityInnerProduct[quregIds[i], quregIds[j]].
CalcDensityInnerProducts[rhoId, omegaIds] returns a vector with i-th element CalcDensityInnerProduct[rhoId, omegaIds[i]].
If all quregs are valid density matrices, the resulting tensors are real, though may have tiny non-zero imaginary components due to numerical imprecision.
For unnormalised density matrices, the tensors may contain complex scalars."
    CalcDensityInnerProducts::error = "`1`"
    
    Circuit::usage = "Circuit[gates] converts a product of gates into a left-to-right circuit, preserving order."
    Circuit::error = "`1`"
    
    Operator::usage = "Operator[gates] converts a product of gates into a right-to-left circuit."
    Operator::error = "`1`"

    CalcExpecPauliString::usage = "CalcExpecPauliString[qureg, pauliString, workspace] evaluates the expected value of a weighted sum of Pauli tensors, of a normalised qureg. workspace must be a qureg of equal dimensions to qureg. qureg is unchanged, and workspace is modified."
    CalcExpecPauliString::error = "`1`"

    ApplyPauliString::usage = "ApplyPauliString[inQureg, pauliString, outQureg] modifies outQureg to be the result of applying the weighted sum of Pauli tensors to inQureg."
    ApplyPauliString::error = "`1`"
    
    ApplyPhaseFunc::usage = "ApplyPhaseFunc[qureg, qubits, f[r], r] multiplies a phase factor e^(i f[r]) onto each amplitude in qureg, where r is substituted with the index of each basis state as informed by the list of qubits (ordered least to most significant), and optional argument BitEncoding.
\[Bullet] qubits is a list of which qubits to include in the determination of the index r for each basis state. For example, qubits={0,1,2} implies the canonical indexing of basis states in a 3-qubit register.
\[Bullet] f[r] must be an exponential polynomial of r, of the form sum_i a_j r^(p_j) where a_j and p_j can be any real number (including negative and fractional).
\[Bullet] f[r] must evaluate to a real number for every basis state index informed by qubits, unless overriden via optional argument PhaseOverrides.
ApplyPhaseFunc[qureg, {qubits, ...}, f[x,y,...], {x,y,...}] evaluates a multi-variable exponential-polynomial phase function, where each variable corresponds to a sub-register of qubits.
ApplyPhaseFunc[qureg, {qubits, ...}, FuncName] evaluates a specific named multi-variable function to determine the phase. These are:
    \[Bullet] \"Norm\" evaluates Sqrt[x^2 + y^2 + ...]
    \[Bullet] {\"InverseNorm\", div} evaluates 1/Sqrt[x^2 + y^2 + ...], replaced by div at divergence (when x=y=...=0).    
    \[Bullet] {\"ScaledNorm\", coeff} evaluates coeff*Sqrt[x^2 + y^2 + ...]
    \[Bullet] {\"ScaledInverseNorm\", coeff, div} evaluates coeff/Sqrt[x^2 + y^2 + ...], replaced by div at divergence (when x=y=...=0). 
    \[Bullet] {\"ScaledInverseShiftedNorm\", coeff, div, \[CapitalDelta]x, \[CapitalDelta]y, ...} evaluates coeff/Sqrt[(x-\[CapitalDelta]x)^2 + (y-\[CapitalDelta]y)^2 + ...], replaced by div at numerical divergence (when the denominator is within machine epsilon to zero). 
    \[Bullet] \"Product\" evaluates x*y*...
    \[Bullet] {\"InverseProduct\", div} evaluates 1/(x*y*...), replaced by div at divergence (when any of x, y, ... = 0).
    \[Bullet] {\"ScaledProduct\", coeff} evaluates coeff*x*y* ...
    \[Bullet] {\"ScaledInverseProduct\", coeff, div} evaluates coeff/(x*y* ...),, replaced by div at divergence (when any of x, y, ... = 0).
    \[Bullet] \"Distance\" evaluates Sqrt[(x1-x2)^2 + (y1-y2)^2 + ...], where sub-registers in {qubits} are assumed to be in order of {x1, x2, y1, y2, ...}
    \[Bullet] {\"InverseDistance\", div} evaluates 1/Sqrt[(x1-x2)^2 + (y1-y2)^2 + ...], replaced by div at divergence (when x1=x2, y1=y2, ...).   
    \[Bullet] {\"ScaledDistance\", coeff} evaluates coeff*Sqrt[(x1-x2)^2 + (y1-y2)^2 + ...]
    \[Bullet] {\"ScaledInverseDistance\", coeff, div} evaluates coeff/Sqrt[(x1-x2)^2 + (y1-y2)^2 + ...], replaced by div at divergence (when x1=x2, y1=y2, ...). 
    \[Bullet] {\"ScaledInverseShiftedDistance\", coeff, div, \[CapitalDelta]x, \[CapitalDelta]y, ...} evaluates coeff/Sqrt[(x1-x2-\[CapitalDelta]x)^2 + (y1-y2-\[CapitalDelta]y)^2 + ...], replaced by div at numerical divergence (when the denominator is within machine epsilon to zero).
    \[Bullet] {\"ScaledInverseShiftedWeightedDistance\", coeff, div, fx, \[CapitalDelta]x, fy, \[CapitalDelta]y, ...} evaluates coeff/Sqrt[fx (x1-x2-\[CapitalDelta]x)^2 + fy (y1-y2-\[CapitalDelta]y)^2 + ...], replaced by div at numerical divergence (when the denominator is within machine epsilon to zero), and when the denominator sqrt argument is negative.   
    Notice the order of parameters matches the ordering of the words in the FuncName.
ApplyPhaseFunc accepts optional arguments BitEncoding and PhaseOverrides.
ApplyPhaseFunc[... PhaseOverrides -> rules] first consults whether a basis state's index is included in the list of rules {index -> phase}, and if present, uses the prescribed phase in lieu of evaluating f[index].
    PhaseOverrides which correspond to divergences of named phase functions will be used, in lieu of the divergence parameter.
    For multi-variable functions, each index must be a tuple.
ApplyPhaseFunc[..., BitEncoding -> \"Unsigned\"] interprets each sub-register state as an unsigned binary integer, in {0, ..., 2^numQubits-1}
ApplyPhaseFunc[..., BitEncoding -> \"TwosComplement\"] interprets each sub-register state as a two's complement signed integer in {-2^(N-1), ..., +2^(N-1)-1}, where N is the number of qubits (including the sign qubit).
See ?BitEncoding and ?PhaseOverrides."
    ApplyPhaseFunc::error = "`1`"
    
    CalcPauliStringMatrix::usage = "CalcPauliStringMatrix[pauliString] returns the numerical matrix of the given real-weighted sum of Pauli tensors. The number of qubits is assumed to be the largest Pauli target. This accepts only sums of Pauli products with unique qubits and floating-point coefficients, and is computed numerically."
    CalcPauliStringMatrix::error = "`1`"
    
    CalcPauliExpressionMatrix::usage = "CalcPauliExpressionMatrix[expr] returns the sparse, analytic matrix given by the symbolic expression of Pauli operators, X, Y, Z, Id. The number of qubits is assumed to be the largest Pauli target. Accepts the same inputs as SimplfyPaulis[], and is computed symbolically.
CalcPauliExpressionMatrix[expr, numQb] overrides the assumed number of qubits."
    CalcPauliExpressionMatrix::error = "`1`"
    
    CalcPauliStringMinEigVal::usage = "CalcPauliStringMinEigVal[pauliString] returns the ground-state energy of the given real-weighted sum of Pauli tensors.
CalcPauliStringMinEigVal[pauliString, MaxIterations -> n] specifies to use at most n iterations in the invoked Arnaldi/Lanczos's method"
    CalcPauliStringMinEigVal::error = "`1`"

    DestroyQureg::usage = "DestroyQureg[qureg] destroys the qureg associated with the given ID. If qureg is a Symbol, it will additionally be cleared."
    DestroyQureg::error = "`1`"
    
    GetAmp::usage = "GetAmp[qureg, index] returns the complex amplitude of the state-vector qureg at the given index, indexing from 0.
GetAmp[qureg, row, col] returns the complex amplitude of the density-matrix qureg at index [row, col], indexing from [0,0]."
    GetAmp::error = "`1`"
    
    SetAmp::usage = "SetAmp[qureg, index, amp] modifies the indexed amplitude of the state-vector qureg to complex number amp.
SetAmp[qureg, row, col, amp] modifies the indexed (row, col) amplitude of the density-matrix qureg to complex number amp"
    SetAmp::error = "`1`"

    GetQuregState::usage = "GetQuregState[qureg, form] returns the state-vector or density matrix amplitudes associated with the given qureg, in the specified form. Options for form are:
\[Bullet] \"ZBasisMatrix\" (default) returns the amplitudes in the standard Z-basis, as a complex vector or matrix.
\[Bullet] \"ZBasisKets\" returns a sum of complex weighted kets (or ket-bra projectors) of qubits in the standard Z-basis.
It is often convenient to pass the returned structure to Chop[] in order to remove negligible terms and numerical artefacts."
    GetQuregState::error = "`1`"
    
    SetQuregMatrix::usage = "SetQuregMatrix[qureg, matr] modifies qureg, overwriting its statevector or density matrix with that passed."
    SetQuregMatrix::error = "`1`"
    
    SetQuregToPauliString::usage = "SetQuregToPauliString[qureg, pauliString] overwrites the given density matrix to become a dense matrix representation of the given pauli string.
The state is likely no longer a valid density matrix but is useful as a persistent Z-basis representation of the pauli string, to be used in functions like CalcDensityInnerProduct[] and CalcExpecPauliStringDerivs[]."
    SetQuregToPauliString::error = "`1`"
    
    GetRandomPauliString::usage = "GetRandomPauliString[numQubits, numTerms, {minCoeff, maxCoeff}] generates a random Pauli string with unique Pauli tensors.
GetRandomPauliString[numQubits, All, {minCoeff, maxCoeff}] will generate all 4^numQubits unique Pauli tensors.
GetRandomPauliString[numQubits, {minCoeff, maxCoeff}] will generate 4 numQubits^4 unique terms / Pauli tensors, unless this exceeds the maximum of 4^numQubits.
GetRandomPauliString[numQubits] will generate random coefficients in [-1, 1].
All combinations of optional arguments are possible."
    GetRandomPauliString::error = "`1`"
    
    CreateRemoteQuESTEnv::usage = "CreateRemoteQuESTEnv[ip, port1, port2] connects to a remote QuESTlink server at ip, at the given ports, and defines several QuEST functions, returning a link object. This should be called once. The QuEST function defintions can be cleared with DestroyQuESTEnv[link]."
    CreateRemoteQuESTEnv::error = "`1`"
    
    CreateLocalQuESTEnv::usage = "CreateLocalQuESTEnv[fn] connects to a local 'quest_link' executable, located at fn, running single-CPU QuEST. This should be called once. The QuEST function defintions can be cleared with DestroyQuESTEnv[link].
CreateLocalQuESTEnv[] connects to a 'quest_link' executable in the working directory."
    CreateLocalQuESTEnv::error = "`1`"
    
    CreateDownloadedQuESTEnv::usage = "CreateDownloadedQuESTEnv[] downloads a precompiled single-CPU QuESTlink binary (specific to your operating system) directly from Github, then locally connects to it. This should be called once, before using the QuESTlink API.
CreateDownloadedQuESTEnv[os] forces downloaded of the binary for operating system 'os', which must one of {Windows, Linux, Unix, MacOS, MacOSX}."
    CreateDownloadedQuESTEnv::error = "`1`"
    
    DestroyQuESTEnv::usage = "DestroyQuESTEnv[link] disconnects from the QuEST link, which may be the remote Igor server or a loca instance, clearing some QuEST function definitions (but not those provided by the QuEST package)."
    DestroyQuESTEnv::error = "`1`"

    SetWeightedQureg::usage = "SetWeightedQureg[fac1, q1, fac2, q2, facOut, qOut] modifies qureg qOut to be (facOut qOut + fac1 q1 + fac2 q2). qOut can be one of q1 an q2, and all factors can be complex.
SetWeightedQureg[fac1, q1, fac2, q2, qOut] modifies qureg qOut to be (fac1 q1 + fac2 q2). qOut can be one of q1 an q2.
SetWeightedQureg[fac1, q1, qOut] modifies qureg qOut to be fac1 * q1. qOut can be q1.
SetWeightedQureg[fac, qOut] modifies qureg qOut to be fac qOut; that is, qOut is scaled by factor fac."
    SetWeightedQureg::error = "`1`"
    
    SimplifyPaulis::usage = "SimplifyPaulis[expr] freezes commutation and analytically simplifies the given expression of Pauli operators, and expands it in the Pauli basis. The input expression can include sums, products, non-commuting products, and powers (with nonzero integer exponents) of (subscripted) Id, X, Y and Z operators and other Mathematica symbols (including variables defined as Pauli expressions, and functions thereof). 
Be careful of performing algebra with Pauli operators outside of SimplifyPaulis[], since Mathematica may erroneously automatically commute them."
    SimplifyPaulis::error = "`1`"

    DrawCircuit::usage = "DrawCircuit[circuit] generates a circuit diagram. The circuit can contain symbolic parameters.
DrawCircuit[circuit, numQubits] generates a circuit diagram with numQubits, which can be more or less than that inferred from the circuit.
DrawCircuit[{circ1, circ2, ...}] draws the total circuit, divided into the given subcircuits. This is the output format of GetCircuitColumns[].
DrawCircuit[{{t1, circ1}, {t2, circ2}, ...}] draws the total circuit, divided into the given subcircuits, labeled by their scheduled times {t1, t2, ...}. This is the output format of GetCircuitSchedule[].
DrawCircuit[{{t1, A1,A2}, {t2, B1,B2}, ...}] draws the total circuit, divided into subcircuits {A1 A2, B1 B2, ...}, labeled by their scheduled times {t1, t2, ...}. This is the output format of InsertCircuitNoise[].
DrawCircuit accepts optional arguments Compactify, DividerStyle, SubcircuitSpacing, SubcircuitLabels, LabelDrawer and any Graphics option. For example, the fonts can be changed with 'BaseStyle -> {FontFamily -> \"Arial\"}'."
    DrawCircuit::error = "`1`"
    
    DrawCircuitTopology::usage = "DrawCircuitTopology[circuit] generates a graph plot of the qubit connectivity implied by the given circuit. The precise nature of the information plotted depends on the following options.
DrawCircuitTopology accepts optional arguments DistinguishBy, ShowLocalGates, ShowRepetitions to modify the presented graph.
DrawCircuitTopology additionally accepts DistinguishedStyles and all options of Graph[], Show[] and LineLegend[] for customising the plot aesthetic."
    DrawCircuitTopology::error = "`1`"

    CalcCircuitMatrix::usage = "CalcCircuitMatrix[circuit] returns an analytic matrix for the given unitary circuit, which may contain symbolic parameters. The number of qubits is inferred from the circuit indices (0 to maximum specified).
CalcCircuitMatrix[circuit] returns an analytic superoperator for the given non-unitary circuit, expressed as a matrix upon twice as many qubits. The result can be multiplied upon a column-flattened density matrix.
CalcCircuitMatrix[circuit, numQubits] forces the number of present qubits.
CalcCircuitMatrix accepts optional argument AsSuperoperator and AssertValidChannels."
    CalcCircuitMatrix::error = "`1`"
    
    GetCircuitGeneralised::usage = "GetCircuitGeneralised[circuit] returns an equivalent circuit composed only of general unitaries (and Matr operators) and Kraus operators of analytic matrices."
    GetCircuitGeneralised::error = "`1`"

    GetCircuitConjugated::usage = "GetCircuitConjugated[circuit] returns a circuit describing the complex conjugate operation of the given circuit. This is not the conjugate-transpose; instead, each operator is replaced with one or more operators described by Z-basis matrices equal to the complex conjugate of the original operator's matrix.
Accepts optional argument AssertValidChannels->False which relaxes the assumption that the circuit's operators are completely-positive and trace-preserving (CPTP). This permits canonical operator parameters (such as rotation strengths and channel probabilities) to be arbitrary complex values.
See ?AssertValidChannels."
    GetCircuitConjugated::error = "`1`"
    
    GetCircuitSuperoperator::usage = "GetCircuitSuperoperator[circuit] returns the corresponding superoperator circuit upon doubly-many qubits as per the Choi–Jamiolkowski isomorphism. Decoherence channels become Matr[] superoperators.
GetCircuitSuperoperator[circuit, numQubits] forces the circuit to be assumed size numQubits, so that the output superoperator acts upon 2*numQubits.
GetCircuitSuperoperator accepts optional argument AssertValidChannels."
    GetCircuitSuperoperator::error = "`1`"
    
    PlotDensityMatrix::usage = "PlotDensityMatrix[matrix] (accepts id or numeric matrix) plots a component (default is magnitude) of the given matrix as a 3D bar plot.
PlotDensityMatrix[matrix1, matrix2] plots both matrix1 and matrix2 simultaneously, and the latter is intended as a \"reference\" state.
PlotDensityMatrix[matrix, vector] converts the state-vector to a density matrix, and plots.
PlotDensityMatrix accepts optional arguments PlotComponent, BarSpacing and all options for Histogram3D. Customising the colour may require overriding the default ColorFunction.
When two matrices are passed, many options (e.g. ChartStyle) can accept a length-2 list."
    PlotDensityMatrix::error = "`1`"
    
    GetCircuitColumns::usage = "GetCircuitColumns[circuit] divides circuit into sub-circuits of gates on unique qubits (i.e. columns), filled from the left. Flatten the result to restore an equivalent but potentially compacted Circuit."
    GetCircuitColumns::error = "`1`"
    
    GetUnsupportedGates::usage = "GetUnsupportedGates[circuit, spec] returns a list of the gates in circuit which either on non-existent qubits or are not present in or satisfy the gate rules in the device specification. The circuit can contain symbolic parameters, though if it cannot be inferred that the parameter satisfies a gate condition, the gate is assumed unsupported.
GetUnsupportedGates[{circ1, circ2, ...}, spec] returns the unsupported gates in each subcircuit, as separate lists.
GetUnsupportedGates[{{t1, circ1}, {t2, circ2}, ...}, spec] ignores the times in the schedule and returns the unsupported gates in each subcircuit, as separate lists."
    GetUnsupportedGates::error = "`1`"
    
    GetCircuitSchedule::usage = "GetCircuitSchedule[circuit, spec] divides circuit into sub-circuits of simultaneously-applied gates (filled from the left), and assigns each a start-time based on the duration of the slowest gate according to the given device specification. The returned structure is {{t1, sub-circuit1}, {t2, sub-circuit2}, ...}, which can be given directly to DrawCircuit[] or ViewCircuitSchedule[].
GetCircuitSchedule[subcircuits, spec] uses the given division (lists of circuits), assumes the gates in each can be performed simultaneously, and performs the same scheduling.
GetCircuitSchedule accepts optional argument ReplaceAliases.
GetCircuitSchedule will take into consideration gates with durations dependent on their scheduled start time."
    GetCircuitSchedule::error = "`1`"
    
    CheckCircuitSchedule::usage = "CheckCircuitSchedule[{{t1, circ1}, {t2, circ2}, ...}, spec] checks whether the given schedule of sub-circuits is compatible with the device specification, can be made compatible, or else if it prescribes overlapping sub-circuit execution (regardless of targeted qubits). Times and gate parameters can be symbolic. All gates in a sub-circuit are assumed applicable simultaneously, even if they target overlapping qubits.
CheckCircuitSchedule returns False if the (possibly symbolic) times cannot possibly be monotonic, nor admit a sufficient duration for any sub-circuit.
CheckCircuitSchedule returns True if the schedule is valid for any assignment of the times and gate parameters.
CheckCircuitSchedule returns a list of symbolic conditions which must be simultaneously satisfied for the schedule to be valid, if it cannot determine so absolutely. These conditions include constraints of both motonicity and duration.
CheckCircuitSchedule will take into consideration gates with durations dependent on their scheduled start time, and circuit variables."
    CheckCircuitSchedule::error = "`1`"
    
    InsertCircuitNoise::usage = "InsertCircuitNoise[circuit, spec] divides the circuit into scheduled subcircuits, then replaces them with rounds of active and passive noise, according to the given device specification. Scheduling is performed by GetCircuitSchedule[]. The output format is {{t1, active, passive}, ...}, which can be given directly to DrawCircuit[], ViewCircuitSchedule[] or ExtractCircuit[].
InsertCircuitNoise[{circ1, circ2, ...}, spec] uses the given list of sub-circuits (output format of GetCircuitColumns[]), assuming each contain gates which can be simultaneously performed.
InsertCircuitNoise[{{t1, circ1}, {t2, circ2}, ...} assumes the given schedule (output format of GetCircuitSchedule[]) of {t1,t2,...} for the rounds of gates and noise. These times can be symbolic.
InsertCircuitNoise accepts optional argument ReplaceAliases.
InsertCircuitNoise can handle gates with time-dependent noise operators and durations."
    InsertCircuitNoise::error = "`1`"
    
    ExtractCircuit::usage = "ExtractCircuit[] returns the prescribed circuit from the outputs of InsertCircuitNoise[], GetCircuitSchedule[] and GetCircuitColumns[]."
    ExtractCircuit::error = "`1`"
    
    ViewCircuitSchedule::usage = "ViewCircuitSchedule[schedule] displays a table form of the given circuit schedule, as output by InsertCircuitNoise[] or GetCircuitSchedule[].
ViewCircuitSchedule accepts all optional arguments of Grid[], for example 'FrameStyle', and 'BaseStyle -> {FontFamily -> \"CMU Serif\"}'."
    ViewCircuitSchedule::error = "`1`"
    
    ViewDeviceSpec::usage = "ViewDeviceSpec[spec] displays all information about the given device specification in table form.
ViewDeviceSpec accepts all optional arguments of Grid[] (to customise all tables), and Column[] (to customise their placement)."
    ViewDeviceSpec::error = "`1`"
    
    CheckDeviceSpec::usage = "CheckDeviceSpec[spec] checks that the given device specification satisfies a set of validity requirements, returning True if so, otherwise reporting a specific error. This is a useful debugging tool when creating a device specification, though a result of True does not gaurantee the spec is valid."
    CheckDeviceSpec::error = "`1`"
    
    GetCircuitInverse::usage = "GetCircuitInverse[circuit] returns a circuit prescribing the inverse unitary operation of the given circuit."
    GetCircuitInverse::error = "`1`"
    
    SimplifyCircuit::usage = "SimplifyCircuit[circuit] returns an equivalent but simplified circuit."
    SimplifyCircuit::error = "`1`"
    
    GetKnownCircuit::usage = "GetKnownCircuit[\"QFT\", qubits]
GetKnownCircuit[\"Trotter\", hamil, order, reps, time]
    (https://arxiv.org/pdf/math-ph/0506007.pdf)
GetKnownCircuit[\"HardwareEfficientAnsatz\", reps, paramSymbol, qubits]
    (https://arxiv.org/pdf/1704.05018.pdf)
GetKnownCircuit[\"TrotterAnsatz\", hamil, order, reps, paramSymbol]
    (https://arxiv.org/pdf/1507.08969.pdf)
GetKnownCircuit[\"LowDepthAnsatz\", reps, paramSymbol, qubits]
    (https://arxiv.org/pdf/1801.01053.pdf)"
    GetKnownCircuit::error = "`1`"
    
    GetCircuitsFromChannel::usage = "GetCircuitsFromChannel[channel] returns a list of all pure, analytic circuits which are admitted as possible errors of the input channel (a circuit including decoherence). Channels which are mixtures of unitaries (like Depol, Deph) become unitaries and a non-unitary Fac[] operator, while other channels (Damp, Kraus) become non-trace-preserving Matr[] operators.
The sum of the expected values of the (potentially unnormalised) state-vectors output by the returned circuits is equivalent to the expected value of the input channel. However, if numerical expectation values are ultimately sought (via Monte Carlo estimation with statevectors), you should instead use SampleExpecPauliString[].
See GetRandomCircuitFromChannel[] to randomly select one of these circuits, weighted by its probability.
See SampleExpecPauliString[] to sample such circuits in order to efficiently approximate the effect of decoherence on an expectation value."
    GetCircuitsFromChannel::error = "`1`"
    
    GetRandomCircuitFromChannel::usage = "GetRandomCircuitFromChannel[channel] returns a pure, random circuit from the coherent decomposition of the input channel (a circuit including decoherence), weighted by its probability. The average of the expected values of the circuits returned by this function approaches the expected value of the noise channel.
    See SampleExpecPauliString[] to sample such circuits in order to efficiently approximate the effect of decoherence on an expectation value."
    GetRandomCircuitFromChannel::error = "`1`"
    
    SampleExpecPauliString::usage = "SampleExpecPauliString[initQureg, channel, pauliString, numSamples] estimates the expected value of pauliString under the given channel (a circuit including decoherence) upon the state-vector initQureg, through Monte Carlo sampling. This avoids the quadratically greater memory costs of density-matrix simulation, but may need many samples to be accurate.
SampleExpecPauliString[initQureg, channel, pauliString, All] deterministically samples each channel decomposition once.
SampleExpecPauliString[initQureg, channel, pauliString, numSamples, {workQureg1, workQureg2}] uses the given persistent working registers to avoid their internal creation and destruction.
To get a sense of the circuits being sampled, see GetCircuitsFromChannel[]. 
Use option ShowProgress to monitor the progress of sampling."
    SampleExpecPauliString::error = "`1`"
    
    SampleClassicalShadow::usage = "SampleClassicalShadow[qureg, numSamples] returns a sequence of pseudorandom measurement bases (X, Y and Z) and their outcomes (as bits) when performed on all qubits of the given input state.
\[Bullet] The output has structure { {bases, outcomes}, ...} where bases is a list of Pauli bases (encoded as 1=X, 2=Y, 3=Z) specified per-qubit, and outcomes are the corresponding classical qubit outcomes (0 or 1).
\[Bullet] Both lists are ordered with least significant qubit (index 0) first.
\[Bullet] The output shadow is useful for efficient experimental estimation of quantum state properties, as per Nat. Phys. 16, 1050–1057 (2020)."
    SampleClassicalShadow::error = "`1`"
    
    CalcExpecPauliProdsFromClassicalShadow::usage = "CalcExpecPauliProdsFromClassicalShadow[shadow, prods] returns a list of expected values of each Pauli product, as prescribed by the given classical shadow (e.g. output from SampleClassicalShadow[]).
CalcExpecPauliProdsFromClassicalShadow[shadow, prods, numBatches] divides the shadow into batches, computes the expected values of each, then returns their medians. This may suppress measurement errors. The default numBatches is 10. 
This is the procedure outlined in Nat. Phys. 16, 1050–1057 (2020)."
    CalcExpecPauliProdsFromClassicalShadow::error = "`1`"

    CalcCircuitGenerator::usage = "CalcCircuitGenerator[circuit] computes the Pauli string generator G of the given circuit, whereby circuit = Exp[i G]. 
\[Bullet] If circuit contains decoherence operators, the generator of the circuit's superoperator is returned. See ?GetCircuitSuperoperator.
\[Bullet] If circuit is unitary, the resulting coefficients may have non-zero imaginary components due to numerical error; these can be removed with Chop[].
\[Bullet] If circuit is a single operator, the resulting Pauli string is automatically simplified.
\[Bullet] Accepts option TransformationFunction -> f, where function f will be applied to the generator's Z-basis matrix before projection into the Pauli basis. This overrides the automatic simplification."
    CalcCircuitGenerator::error = "`1`"

    GetCircuitRetargeted::usage = "GetCircuitRetargeted[circuit, rules] returns the given circuit but with its target and control qubits modified as per the given rules. The rules can be anything accepted by ReplaceAll.
For instance GetCircuitRetargeted[..., {0->1, 1->0}] swaps the first and second qubits, and GetCircuitRetargeted[..., q_ -> q + 10] shifts every qubit up by 10.
This function modifies only the qubits in the circuit, carefully avoiding modifying gate arguments and other data, so it is a safe alternative to simply evaluating (circuit /. rules).
Custom user gates are supported provided they adhere to the standard QuESTlink subscript format."
    GetCircuitRetargeted::error = "`1`"

    GetCircuitQubits::usage = "GetCircuitQubits[circuit] returns a list of all qubit indices featured (i.e. controlled upon or targeted by gates) in the given circuit. The order of the returned qubits matches the order they first appear in the circuit, and within a gate, by the target then control qubits in the user-given order (with duplicates deleted)."
    GetCircuitQubits::error = "`1`"

    GetCircuitCompacted::usage = "GetCircuitCompacted[circuit] returns {out, map} where out is an equivalent circuit but which targets only the lowest possible qubits, and map is a list of rules to restore the original qubits.
This is useful for computing the smallest-form matrix of gates which otherwise target large-index qubits, via CalcCircuitMatrix @ First @ GetCircuitCompacted @ gate.
The order of the target and control qubits in the first returned gate are strictly increasing, so GetCircuitCompacted[gate] is also useful for mapping gates to a unique form irrespective of their qubits.
The original circuit is restored by GetCircuitRetargeted[out, map]."
    GetCircuitCompacted::error = "`1`"

    GetCircuitParameterised::usage = "GetCircuitParameterised[circuit, paramSymbol] returns {out, paramValues} where out is an equivalent circuit whereby each scalar gate parameter (like those to Rx, R, G, etc) has been substituted with paramSymbol[i]. The returned paramValues is a list of symbol substitutions, so that the original circuit is obtained with out /. paramValues.
This function is useful for tasks like obtaining gate strengths, finding repeated parameters, or transforming circuits into variational ansatze. Note that custom gates in the QuESTlink format are permitted, but will not be considered for parameterisation.
GetCircuitParameterised accepts the below options.
\[Bullet] \"UniqueParameters\" -> True will force every substituted gate to receive a unique symbol (i.e. paramSymbol[i] for unique i), even if multiple gates have the same scalar parameter. Otherwise, gates with the same scalar parameter will automatically use the same repeated symbol, shrinking the length of paramValues.
\[Bullet] \"ExcludeChannels\" -> False will permit scalar-parameterised decoherence channels (like Damp, Depol, etc) to be parameterised in the output.
\[Bullet] \"ExcludeGates\" -> gatePattern(s) will prevent gates matching the given pattern (or list of patterns) from being parameterised. Note that gates and their controlled variants are treated separately.
\[Bullet] \"ExcludeParameters\" -> paramPattern(s) will prevent any gate parameter matching the given pattern (or list of patterns) from being substituted."
    GetCircuitParameterised::error = "`1`"

    RecompileCircuit::usage = "RecompileCircuit[circuit, method] returns an equivalent circuit, transpiled to a differnet gate set. The input circuit can contain any unitary gate, with any number of control qubits. Supported methods include:
\[Bullet] \"SingleQubitAndCNOT\" decompiles the circuit into canonical single-qubit gates (H, Ph, T, S, X, Y, Z, Rx, Ry, Rz), a global phase G, and two-qubit C[X] gates. This method uses a combination of 23 analytic and numerical decompositions.
\[Bullet] \"CliffordAndRz\" decompiles the circuit into Clifford gates (H, S, X, Y, Z, CX, CY, CZ, SWAP), a global phase G, and non-Clifford Rz.
Note that the returned circuits are not necessarily optimal/minimal, and may benefit from a subsequent call to SimplifyCircuit[]. "
    RecompileCircuit::error = "`1`"

    CalcPauliTransferMatrix::usage = "CalcPauliTransferMatrix[circuit] returns a single PTM operator equivalent to the given circuit.
CalcPauliTranferMatrix /@ circuit returns an equivalent sequence of individual (and likely smaller) PTM operators.
CalcPauliTransferMatrix accepts optional argument AssertValidChannels."
    CalcPauliTransferMatrix::error = "`1`"

    CalcPauliTransferMap::usage = "CalcPauliTransferMap[ptm] produces a PTMap equivalent to the given PTM operator. See ?PTM.
CalcPauliTransferMap[circuit] produces a PTMap from the given gate or circuit, by merely first invoking CalcPauliTransferMatrix[].
The returned map encodes how each basis Pauli-string (encoded by its integer index) is mapped to a weighted sum of other strings (encoded as {index, coefficient} pairs) by the PTM. The indexing convention is the same as used by GetPauliString[] where the subscripted qubits of the PTM are treated as though given in order of increasing significance.
For improved performance, gate parameters should be kept symbolic (and optionally substituted thereafter) so that algebraic simplification can identify zero elements without interference by finite-precision numerical errors.
CalcPauliTransferMap also accepts option AssertValidChannels->False to disable the automatic simplification of the map's coefficients through the assertion of valid channel parameters. See ?AssertValidChannels."
    CalcPauliTransferMap::error = "`1`"

    DrawPauliTransferMap::usage = "DrawPauliTransferMap[map] visualises the given PTMap as a graph where nodes are basis Pauli strings, and edges indicate the transformative action of the map.
DrawPauliTransferMap also accepts PTM, circuit and gate instances, for which the corresponding PTMap is automatically calculated.
DrawPauliTransferMap accepts options \"PauliStringForm\", \"ShowCoefficients\" and \"EdgeDegreeStyles\", in addition to all options accepted by Graph[].
\[Bullet] \"ShowCoefficients\" -> False hides the map's Pauli string coefficients which are otherwise shown as edge labels.
\[Bullet] \"PauliStringForm\" sets the vertex label format to one of \"Subscript\" (default), \"Index\", \"Kronecker\", \"String\" or \"Hidden\". These (except the latter) are the formats are supported by GetPauliStringReformatted[].
\[Bullet] \"EdgeDegreeStyles\" specifies a list of styles (default informed by ColorData[\"Pastel\"]) to set upon edges from nodes with increasing outdegree. For example, \"EdgeDegreeStyles\"->{Red,Green,Blue} sets edges from Pauli states which are mapped to a single other state to the colour Red, but two-outdegree node out-edges become Green, and three-outdegree become Blue. The list is assumed repeated for higher outdegree nodes than specified.
\[Bullet] Graph[] options override these settings, so specifying EdgeStyle -> Black will set all edges to Black regardless of their node's outdegree."
    DrawPauliTransferMap::error = "`1`"

    ApplyPauliTransferMap::usage = "ApplyPauliTransferMap[pauliString, ptMap] returns the Pauli string produced by the given PTMap acting upon the given initial Pauli string.
ApplyPauliTransferMap[pauliString, circuit] automatically transforms the given circuit (composed of gates, channels, and PTMs, possibly intermixed) into PTMaps before applying them to the given Pauli string.
For improved performance, gate parameters should be kept symbolic (and optionally substituted thereafter) so that algebraic simplification can identify zero elements without interference by finite-precision numerical errors.
This method uses automatic caching to avoid needless re-computation of an operator's PTMap, agnostic to the targeted and controlled qubits, at the cost of additional memory usage. Caching behaviour can be controlled using option \"CacheMaps\":
\[Bullet] \"CacheMaps\" -> \"UntilCallEnd\" (default) caches all computed PTMaps but clears the cache when ApplyPauliTransferMap[] returns.
\[Bullet] \"CacheMaps\" -> \"Forever\" maintains the cache even between multiple calls to ApplyPauliTransferMap[].
\[Bullet] \"CacheMaps\" -> \"Never\" disables caching (and clears the existing cache before computation), re-computing each operqtors' PTMap when encountered in the circuit.
ApplyPauliTransferMap also accepts all options of CalcPauliTransferMap, like AssertValidChannels. See ?AssertValidChannels."
    ApplyPauliTransferMap::error = "`1`"

    CalcPauliTransferEval::usage = "CalcPauliTransferEval[pauliString, ptMaps] returns the full evolution history of the given Pauli string under the given list of PTMap operators. This is often unnecessary to call directly - most users can call ApplyPauliTransferMap[] or DrawPauliTransferEval[] instead - unless you wish to store or process the evaluation history.
CalcPauliTransferEval[pauliString, circuit] evolves the Pauli string under the PTMaps automatically calculated from the given circuit. 
There are two possible return formats, informed by option \"OutputForm\", which are respectively fast and slow to evaluate, and both of which can be passed to functions like DrawPauliTransferEval[].
The \"Simple\" output is a list of sublists, each corresponding to a layer in the evaluation history (i.e. the operation of a PTMap upon the current Pauli string) including the initial Pauli string. Each item therein represents a Pauli product state and has form {prod,id,parents} where 'prod' is a Pauli basis state expressed in base-4 digits (see ?GetPauliStringReformatted), 'id' is a unique integer identifying the state, and 'parents' is a list of tuples of form {parentId, factor}. These indicate the ancestor Pauli states from which the id'd state was produced under the action of the previous PTMap, and the factor that the map multiplies upon that parent state. The basis products of the initial state have parentId=0.
The \"Detailed\" output is an Association with the following items:
\[Bullet] \"Ids\" is a list of integers uniquely identifying each node in the evaluation graph. Note these are not gauranteed to be contiguous due to the merging of incident Pauli states (see \"CombineStrings\" below).
\[Bullet] \"Layers\" groups \"Ids\" into sublists according to their depth in the graph, i.e. which ptMap produced the node. There are Length[ptMaps]+1 layers, including the initial pauliString layer.
\[Bullet] \"States\" is an Association of id -> pauliProduct, identifying the Pauli basis state associated with the id'd node.
\[Bullet] \"Parents\" is an Association of id -> list of parent ids. A node's parents are the states of the previous layer who were modified by the previous layer's PTMap to the node's state.
\[Bullet] \"Children\" is an Association of id -> list of child ids. A node's children are the states the node is transformed to when modified by the next layer's PTMap.
\[Bullet] \"ParentFactors\" is an Association of id -> Association, where the inner Association is of parentId -> coefficient. The inner Association records the factors multiplied upon the parents when the PTMap produced the node's state.
\[Bullet] \"Weights\" is an Association of id -> weight, where weight is the number of non-identity Paulis in the id'd nodes state.
\[Bullet] \"Indegree\" is an Association of id -> degree, indicating the number of parents. 
\[Bullet] \"Outdegree\" is an Association of id -> degree, indicating the number of children.
\[Bullet] \"Coefficients\" is an Association of id -> coeff, where coeff is the coefficient of the id'd node's Pauli basis state at the node's layer of evaluation.
\[Bullet] \"Strings\" is a list of sums of weighted Pauli strings; one for each layer of evaluation. The resulting Pauli string of the full circuit upon the initial Pauli string is the Last item of this list. The strings are not automatically simplified, so each might be worth passing to SimplifyPaulis[].
\[Bullet] \"NumQubits\" is the number of qubits assumed during the evaluation, informed by the initial Pauli string and PTMaps.
\[Bullet] \"NumNodes\" is the total number of nodes (or basis Pauli states) processed during evaluation. This is merely the length of \"Ids\".
\[Bullet] \"NumLeaves\" is the number of nodes in the final layer, equivalent to the number of Pauli products in the output string.
CalcPauliTransferEval accepts the below options:
\[Bullet] \"OutputForm\" -> \"Simple\" (default) or \"Detailed\", as explained above.
\[Bullet] \"CombineStrings\" -> False which disables combining incident Pauli strings, so that the result is an acyclic tree, and each node has a single parent.
\[Bullet] \"CacheMaps\" which controls the automatic caching of generated PTMaps (see ?ApplyPauliTransferMap).
\[Bullet] AssertValidChannels -> False which disables the simplification of symbolic Pauli string coefficients (see ?AssertValidChannels)."
    CalcPauliTransferEval::error = "`1`"

    DrawPauliTransferEval::usage = "DrawPauliTransferEval[pauliString, circuit] renders and returns a graph of the evaluation of 'circuit' when converted to a series of Pauli transfer maps, acting upon the given initial Pauli string.
DrawPauliTransferEval[data] renders the pre-computed evaluation graph 'data' as output by CalcPauliTransferEval[].
DrawPauliTransferEval accepts all options to Graph[], CalcPauliTransferEval[], DrawPauliTransferMap[], and some additional options, which we summarise below.
\[Bullet] \"HighlightPathTo\" -> pauliString (or a list of Pauli strings) highlights all edges ultimately contributing to the coefficient of the specified final pauliString(s). Symbolically weighted sums of Pauli strings are also accepted, in which case all edges to all non-orthogonal Pauli strings are highlighted.
\[Bullet] \"CombineStrings\" -> False disables combining incident Pauli strings so that the result is an (likely significantly larger) acyclic tree.
\[Bullet] \"PauliStringForm\" sets the vertex label format to one of \"String\", \"Hidden\" (these are the defaults depending on graph size), \"Index\", \"Kronecker\", or \"Subscript\". See ?GetPauliStringReformatted.
\[Bullet] \"ShowCoefficients\" -> True or False explicitly shows or hides the PTMap coefficient associated with each edge. The default is Automatic which auto-hides edge labels if there are too many.
\[Bullet] \"EdgeDegreeStyles\" specifies the style of edges from nodes of increasing outdegree. See ?DrawPauliTransferMap.
\[Bullet] \"CacheMaps\" controls the automatic caching of generated PTMaps. See ?ApplyPauliTransferMap.
\[Bullet] AssertValidChannels -> False disables the simplification of symbolic Pauli string coefficients, only noticeable when \"ShowCoefficients\"->True. See ?AssertValidChannels.
\[Bullet] Graph[] options override these settings. For example, specifying EdgeStyle -> Black will set all edges to Black regardless of their node's outdegree."
    DrawPauliTransferEval::error = "`1`"

    GetPauliString::usage = "Returns a Pauli string or a weighted sum of symbolic Pauli tensors from a variety of input formats.
GetPauliString[matrix] returns a complex-weighted sum of Pauli tensors equivalent to the given matrix. If the input matrix is Hermitian, the output can be passed to Chop[] in order to remove the negligible imaginary components.
GetPauliString[index] returns the basis Pauli string corresponding to the given index, where the returned Pauli operator targeting 0 is informed by the least significant bit(s) of the index. 
GetPauliString[digits] specifies the Pauli product via the base-4 digits of its index, where the rightmost digit is the least significant.
GetPauliString[address] opens or downloads the file at address (a string, of a file location or URL), and interprets it as a list of coefficients and Pauli codes. Each line of the file is assumed a separate Pauli tensor with format {coeff code1 code2 ... codeN} (excluding braces) where the codes are in {0,1,2,3} (indicating a I, X, Y, Z), for an N-qubit Pauli string, and are given in order of increasing significance (zero qubit left). Each line must have N+1 terms, which includes the initial real decimal coefficient. For an example, see \"https://qtechtheory.org/hamil_6qbLiH.txt\".
GetPauliString[..., numPaulis] forces the output to contain the given number of Pauli operators, introducing additional Id operators upon un-targeted qubits (unless explicitly removed with \"RemoveIds\"->True).
GetPauliString[..., {targets}] specifies a list of qubits which the returned Pauli string should target (in the given order), instead of the default targets {0, 1, 2, ...}. Targeted Ids are retained.
GetPauliString[..., {targets}, numPaulis] (in either order) specifies the targets, and thereafter pads the output with Ids to achieve the specified number of Pauli operators.
GetPauliString accepts optional argument \"RemoveIds\" -> True or False (default Automatic) which when True, retains otherwise removed Id operators."
    GetPauliString::error = "`1`"

    GetPauliStringRetargeted::usage = "GetPauliStringRetargeted[string, rules] returns the given Pauli string but with its target qubits modified as per the given rules. The rules can be anything accepted by ReplaceAll.
For instance GetPauliStringRetargeted[..., {0->1, 1->0}] swaps the first and second qubits, and GetPauliStringRetargeted[..., q_ -> q + 10] shifts every qubit up by 10.
This function modifies only the qubits in the Pauli string and avoids modifying coefficients, so it is a safe alternative to simply evaluating (string /. rules)."
    GetPauliStringRetargeted::error = "`1`"

    GetPauliStringReformatted::usage = "Reformats symbolic Pauli strings into a variety of other formats convenient for processing.
GetPauliStringReformatted[product, \"Index\"] returns the integer index of the given Pauli product in the ordered basis of Pauli products. The zero target is treated as least significant.
GetPauliStringReformatted[string, \"Index\"] returns a list of {index, coefficient} pairs which describe all Pauli products in the given string.
GetPauliStringReformatted[..., \"Digits\"] returns the individual digits of the basis Pauli string's index (or indices), in base 4, where the rightmost digit is the least significant. 
GetPauliStringReformatted[..., \"Kronecker\"] expands the Pauli string into an explicit Kronecker form. The zero target in the given product corresponds to the rightmost Pauli in the Kronecker form. 
GetPauliStringReformatted[..., \"String\"] returns a compact, string-form of the \"Kronecker\" format.
GetPauliStringReformatted[..., numQubits] expands the \"Digits\", \"Kronecker\" and \"String\" formats to the specified number of qubits, by padding with '0' digits or 'Id' operators."
    GetPauliStringReformatted::error = "`1`"

    GetPauliStringOverlap::usage = "GetPauliStringOverlap[a, b] returns the Pauli products common to both given weighted sums of Pauli strings, with coefficients equal to the conjugate of the 'a' coefficients multiplied by those of 'b'."
    GetPauliStringOverlap::error = "`1`"

    
    (*
     * optional arguments to public functions
     *)
     
    BeginPackage["`Option`"]

    WithBackup::usage = "Optional argument to ApplyCircuit, indicating whether to create a backup during circuit evaluation to restore the input state in case of a circuit error. This incurs additional memory (default True). If the circuit contains no error, this option has no effect besides wasting memory."
    
    ShowProgress::usage = "Optional argument to ApplyCircuit and SampleExpecPauliString, indicating whether to show a progress bar during circuit evaluation (default False). This slows evaluation slightly."
    
    PlotComponent::Usage = "Optional argument to PlotDensityMatrix, to plot the \"Real\", \"Imaginary\" component of the matrix, or its \"Magnitude\" (default)."
    
    Compactify::usage = "Optional argument to DrawCircuit, to specify (True or False) whether to attempt to compactify the circuit (or each subcircuit) by left-filling columns of gates on unique qubits (the result of GetCircuitColumns[]). No compactifying may yield better results for circuits with multi-target gates (which invoke swaps)."
    
    DividerStyle::usage = "Optional argument to DrawCircuit, to style the vertical lines separating subcircuits. Use DividerStyle -> None to draw without dividers, and DividerStyle -> Directive[...] to specify multiple styles properties."
    
    SubcircuitSpacing::usage = "Optional argument to DrawCircuit, to specify the horizontal space inserted between subcircuits."
    
    SubcircuitLabels::usage = "Optional argument to DrawCircuit, specifying the list of labels to display between subcircuits. Use 'None' to skip a label while still drawing the divider (except for the first and last divider). Customise these labels with LabelDrawer."
    
    LabelDrawer::usage = "Optional argument to DrawCircuit, to specify a two-argument function for drawing subcircuit labels. For example, Function[{msg,x},Text[msg,{x,-.5}]]. Use LabelDrawer -> None to show no labels."
    
    ShowLocalGates::usage = "Optional argument to DrawCircuitTopology, to specify (True or False) whether single-qubit gates should be included in the plot (as single-vertex loops)."
    
    ShowRepetitions::usage = "Optional argument to DrawCircuitTopology, to specify (True or False) whether repeated instances of gates (or other groups as set by DistinguishBy) in the circuit should each yield a distinct edge.
For example, if ShowRepetitions -> True and DistinguishBy -> \"Qubits\", then a circuit containing three C[Rz] gates between qubits 0 and 1 will produce a graph with three edges between vertices 0 and 1."
    
    DistinguishBy::usage = "Optional argument to DrawCircuitTopology to specify how gates are aggregated into graph edges and legend labels. The possible values (in order of decreasing specificity) are \"Parameters\", \"Qubits\", \"NumberOfQubits\", \"Gates\", \"None\", and a distinct \"Connectivity\" mode.
DistinguishBy -> \"Parameters\" assigns every unique gate (even distinguishing similar operators with different parameters) its own label.
DistinguishBy -> \"Qubits\" discards gate parameters, but respects target qubits, so will assign similar gates (acting on the same qubits) but with different parameters to the same label.
DistinguishBy -> \"NumberOfQubits\" discards gate qubit indices, but respects the number of qubits in a gate. Hence, for example, similar gates controlled on different pairs of qubits will be merged together, but not with the same gate controlled on three qubits.
DistinguishBy -> \"Gates\" respects only the gate type (and whether it is controlled or not), and discards all qubit and parameter information. Hence similar gates acting on different numbers of qubits will be merged to one label. This does not apply to pauli-gadget gates R, which remain distinguished for unique pauli sequences (though discarding qubit indices).
DistinguishBy -> \"None\" performs no labelling or distinguishing of edges.
DistinguishBy -> \"Connectivity\" merges all gates, regardless of type, acting upon the same set of qubits (orderless)."

    DistinguishedStyles::usage = "Optional argument to DrawCircuitTopology, to specify the colours/styles used for each distinguished group (hence ultimately, the edge and legend styles). This must be a list of graphic directives, and will be repeated if it contains too few elements.
DistinguishedStyles -> Automatic will colour the groups by sampling ColorData[\"Rainbow\"]."
        
    ReplaceAliases::usage = "Optional argument to GetCircuitSchedule and InsertCircuitNoise, specifying (True or False) whether to substitute the device specification's alias operators in the output (including in gates and active/passive noise). 
This is False by default, but must be True to pass the output circuits to (for example) ApplyCircuit which don't recognise the alias.
Note if ReplaceAliases -> True, then the output of GetCircuitSchedule might not be compatible as an input to InsertCircuitNoise."

    PhaseOverrides::usage = "Optional argument to ApplyPhaseFunc, specifying overriding values of the phase function for specific sub-register basis states. This can be used to avoid divergences in the phase function.
For a single-variable phase function, like ApplyPhaseFunc[..., x^2, x], the option must have form PhaseOverrides -> {integer -> real, ...}, where 'integer' is the basis state index of which to override the phase.
For a multi-variable phase function, like ApplyPhaseFunc[..., x^2+y^2, {x,y}], the option must have form PhaseOverrides -> {{integer, integer} -> real, ...}, where the basis state indices are specified as a tuple {x,y}.
Note under BitEncoding -> \"TwosComplement\", basis state indices can be negative."
    
    BitEncoding::usage = "Optional argument to ApplyPhaseFunc, specifying how the values of sub-register basis states are encoded in (qu)bits.
BitEncoding -> \"Unsigned\" (default) interprets basis states as natural numbers {0, ..., 2^numQubits-1}.
BitEncoding -> \"TwosComplement\" interprets basis states as two's complement signed numbers, {0, ... 2^(numQubits-1)-1} and {-1, -2, ... -2^(numQubits-1)}. The last qubit in a sub-register list is assumed the sign bit."

    AsSuperoperator::usage = "Optional argument to CalcCircuitMatrix (default Automatic), specifying whether the output should be a 2^N by 2^N unitary matrix (False), or a 2^2N by 2^2N superoperator matrix (True). The latter can capture decoherence, and be multiplied upon column-flattened 2^2N vectors."
    
    AssertValidChannels::usage = "Optional argument to functions like CalcCircuitMatrix, CalcPauliTransferMatrix, GetCircuitConjugated, etc, specifying whether to simplify their outputs by asserting that all channels therein are completely-positive and trace-preserving (default True).
For example, this asserts that the symbolic argument to a damping channel is constrained between 0 and 1 (inclusive), and that the parameters of canonical parameterised gates (like Rx) are strictly real.
Specifying AssertValidChannels->False will not change the dimension of the outputs (i.e. the returned objects would be applied upon states in the same fashion), but will disable symbolic simplifications therein, and is necessary to obtain correct expressions when all symbolic parameters are permitted to be complex."
    
    EndPackage[]
    
    
    
    (* 
     * gate symbols    
     *)
     
    BeginPackage["`Gate`"]

    H::usage = "H is the Hadamard gate."
    Protect[H]
        
    X::usage = "X is the Pauli X gate, a.k.a NOT or bit-flip gate."
    Protect[X]
    
    Y::usage = "Y is the Pauli Y gate."
    Protect[Y]
    
    Z::usage = "Z is the Pauli Z gate."
    Protect[Z]
    
    Rx::usage = "Rx[\[Theta]] is a rotation of \[Theta] around the x-axis of the Bloch sphere, Exp[-\[ImaginaryI] \[Theta]/2 X \[CircleTimes] X \[CircleTimes]...]."        
    Protect[Rx]
    
    Ry::usage = "Ry[\[Theta]] is a rotation of \[Theta] around the y-axis of the Bloch sphere, Exp[-\[ImaginaryI] \[Theta]/2 Y \[CircleTimes] Y \[CircleTimes]...]." 
    Protect[Ry]
    
    Rz::usage = "Rz[\[Theta]] is a rotation of \[Theta] around the z-axis of the Bloch sphere, Exp[-\[ImaginaryI] \[Theta]/2 Z \[CircleTimes] Z \[CircleTimes]...]." 
    Protect[Rz]
    
    R::usage = "R[\[Theta], paulis] is the unitary Exp[-\[ImaginaryI] \[Theta]/2 \[CircleTimes] paulis]."   
    Protect[R]
    
    S::usage = "S is the S gate, a.k.a. PI/2 gate."
    Protect[S]
    
    T::usage = "T is the T gate, a.k.a PI/4 gate."
    Protect[T]
    
    U::usage = "U[matrix] is a general unitary gate with any number of target qubits, specified as a unitary square complex matrix.
U[list] specifies a diagonal matrix with any number ofg target qubits, specifying only a list of the diagonal elements; this quadratically shrinks memory and runtime costs.
If the given matrix is intended unitarity but is numerically non-unitary due to finite precision effects, use UNonNorm. 
To specify a general non-unitary matrix, use Matr."
    Protect[U]
    
    Deph::usage = "Deph[prob] is a 1 or 2 qubit dephasing with probability prob of error."
    Protect[Deph]
    
    Depol::usage = "Depol[prob] is a 1 or 2 qubit depolarising with probability prob of error."
    Protect[Depol]
    
    Damp::usage = "Damp[prob] is 1 qubit amplitude damping with the given decay probability."
    Protect[Damp]
    
    SWAP::usage = "SWAP is a 2 qubit gate which swaps the state of two qubits."
    Protect[SWAP]
    
    M::usage = "M is a destructive measurement gate which measures the indicated qubits in the Z basis. Targeting multiple qubits is the same as applying M to each in-turn, though their outcomes will be grouped in the output of ApplyCircit[]."
    Protect[M]
    
    P::usage = "P[val] is a (normalised) projector onto {0,1} (i.e. a forced measurement) such that the target qubits represent integer val in binary (right most target takes the least significant digit in val).
P[outcome1, outcome2, ...] is a (normalised) projector onto the given {0,1} outcomes. The left most qubit is set to the left most outcome.
P[{outcome1, outcome2, ...}] is as above.
The probability of the forced measurement outcome (as if it were hypothetically not forced) is included in the output of ApplyCircuit[].
Projection into zero-probability states is invalid and will throw an error."
    Protect[P]
    
    Kraus::usage = "Kraus[ops] applies a one or two-qubit Kraus map (given as a list of Kraus operators) to a density matrix.
Unlike U, UNonNorm and Matr, these operators must be specified as full, dense matrices, and cannot be specified as the diagonal elements of diagonal matrices."
    Protect[Kraus]
    
    KrausNonTP::usage = "KrausNonTP[ops] is equivalent to Kraus[ops] but does not explicitly check that the map is trace-presering. It is still assumed a completely-positive trace-preserving map for internal algorithms, but will tolerate numerical imperfection."
    Protect[KrausNonTP]
    
    G::usage = "G[\[Theta]] applies a global phase rotation of phi, by premultiplying Exp[\[ImaginaryI] \[Theta]]."
    Protect[G]
    
    Id::usage = "Id is an identity gate which effects no change, but can be used for forcing gate alignment in DrawCircuit, or as an alternative to removing gates in ApplyCircuit."
    Protect[Id]
 
    Ph::usage = "Ph is the phase shift gate, which introduces phase factor exp(i*theta) upon state |1...1> of the target and control qubits. The gate is the same under different orderings of qubits, and division between control and target qubits."
    Protect[Ph]
    
    UNonNorm::usage = "UNonNorm[matrix] is treated like a general unitary gate U, but with relaxed normalisation conditions on the matrix.
UNonNorm[list] specifies a diagonal matrix via only the diagonal elements; this quadratically shrinks memory and runtime costs.
UNonNorm is distinct from Matr which is internally treated as a non-unitary operator."
    Protect[UNonNorm]
    
    Matr::usage = "Matr[matrix] is an arbitrary operator with any number of target qubits, specified as a completely general (even non-unitary) square complex matrix.
Matr[list] specifies a diagonal matrix via only the diagonal elements; this quadratically shrinks memory and runtime costs.
Unlike UNonNorm, the given matrix is not internally treated as a unitary matrix. For instance, it is only left-multiplied onto density matrices."
    Protect[Matr]
    
    Fac::usage = "Fac[scalar] is a non-physical operator which multiplies the given complex scalar onto every amplitude of the quantum state. This is directly multiplied onto state-vectors and density-matrices, and may break state normalisation."
    Protect[Fac]

    PTM::usage = "PTM[matrix] is a Pauli-transfer matrix representation of an operator or channel. The subscript indices specify which Paulis of a Pauli string are operated upon. Such objects are produced by functions like CalcPauliTransferMatrix[]."
    Protect[PTM]

    PTMap::usage = "PTMap[map] is a representation of a Pauli transfer matrix as a map between Pauli tensors, specified either as basis-state indices or in a Kronecker form. See ?CalcPauliTransferMap."
    Protect[PTMap]

    (* overriding Mathematica's doc for C[i] as i-th default constant *)
    C::usage = "C is a declaration of control qubits (subscript), which can wrap other gates to conditionally/controlled apply them."
    Protect[C]
 
    EndPackage[]
 
 
 
    (* 
     * device specification keys
     *)
 
    BeginPackage["`DeviceSpec`"]
    
    DeviceDescription::usage = "A description of the specified device."
    
    NumAccessibleQubits::usage = "The number of qubits which can be targeted by user-given circuits in the represented device. These are assumed to be at adjacent indices, starting at 0."
    
    NumTotalQubits::usage = "The number of qubits targeted by all noise in the represented device. This can exceed 'NumAccessibleQubits', since it includes hidden qubits used for advanced noise modelling. Hidden qubits are assumed to start at index 'NumAccessibleQubits'."
    
    Aliases::usage = "Custom aliases for general unitary gates or sub-circuits, recognised by the device specification as elementary gates (optional)."
    
    Gates::usage = "The gates supported by the device, along with their duration and effective operation under active noise."
    
    Qubits::usage = "The qubit properties of the device, such as their passive noise."
    
    NoisyForm::usage = "The channel (expressed as a sub-circuit) describing the noisy, imperfect operation of a device gate."
    
    PassiveNoise::usage = "The channel (expressed as a sub-circuit) describing the passive decoherence of a qubit when not being operated upon by gates."
    
    GateDuration::usage = "The duration of performing a gate on the represented device."
    
    TimeSymbol::usage = "The symbol representing the start time (in a scheduled circuit) of gates and noise channels, which can inform their properties (optional)."
    
    DurationSymbol::usage = "The symbol representing the duration (in a scheduled circuit) of gates or noise channels, which can inform their properties (optional)."
    
    InitVariables::usage = "The function to call at the start of circuit/schedule processing, to re-initialise circuit variables (optional)."
    
    UpdateVariables::usage = "The function to call after each active gate or processed passive noise, to update circuit variables (optional)."
    
    EndPackage[]
    
    
    
    (*
     * deprecated but backwards-compatible API 
     *)
     
    BeginPackage["`Deprecated`"]
    
    CalcExpecPauliProd::usage = "This function is deprecated. Please instead use CalcExpecPauliString."
    CalcExpecPauliSum::usage = "This function is deprecated. Please instead use CalcExpecPauliString."
    ApplyPauliSum::usage = "This function is deprecated. Please instead use ApplyPauliString."
    CalcPauliSumMatrix::usage = "This function is deprecated. Please instead use CalcPauliStringMatrix."
    GetPauliSumFromCoeffs::usage = "This function is deprecated. Please instead use GetPauliString."
    GetPauliStringFromMatrix::usage = "This function is deprecated. Please instead use GetPauliString."
    MixDamping::usage = "This function is deprecated. Please instead use ApplyCircuit with gate Damp."
    MixDephasing::usage = "This function is deprecated. Please instead use ApplyCircuit with gate Deph."
    MixDepolarising::usage = "This function is deprecated. Please instead use ApplyCircuit with gate Depol."
    MixTwoQubitDephasing::usage = "This function is deprecated. Please instead use ApplyCircuit with gate Deph."
    MixTwoQubitDepolarising::usage = "This function is deprecated. Please instead use ApplyCircuit with gate Depol."
    CalcQuregDerivs::usage = "This function is deprecated. Please instead use ApplyCircuitDerivs."
    GetQuregMatrix::usage = "This function is deprecated. Please instead use GetQuregState."
    RetargetCircuit::usage = "This function is deprecated. Please instead use GetCircuitRetargeted."
    
    EndPackage[]
 
 
 
    (* 
     * internal private functions, and definitions of public API
     *)
 
    Begin["`Private`"]
    
    
        
        (*
         * deprecated definitions
         *)
         
        CalcExpecPauliProd[args___] := (
            Message[CalcExpecPauliString::error, "The function CalcExpecPauliProd[] is deprecated. Use CalcExpecPauliString[] or temporarily hide this message using Quiet[]."]; 
            CalcExpecPauliString[args])
        CalcExpecPauliSum[args___] := (
            Message[CalcExpecPauliString::error, "The function CalcExpecPauliSum[] is deprecated. Use CalcExpecPauliString[] or temporarily hide this message using Quiet[]."]; 
            CalcExpecPauliString[args])
        ApplyPauliSum[args___] := (
            Message[ApplyPauliString::error, "The function ApplyPauliSum[] is deprecated, though has still been performed. In future, please use ApplyPauliString[] or temporarily hide this message using Quiet[]."]; 
            ApplyPauliString[args])
        CalcPauliSumMatrix[args___] := (
            Message[CalcPauliStringMatrix::error, "The function CalcPauliSumMatrix[] is deprecated. Use CalcPauliStringMatrix[] or temporarily hide this message using Quiet[]."]; 
            CalcPauliStringMatrix[args])
        GetPauliSumFromCoeffs[args___] := (
            Message[GetPauliString::error, "The function GetPauliSumFromCoeffs[] is deprecated. Use GetPauliString[] or temporarily hide this message using Quiet[]."]; 
            GetPauliString[args])

        GetPauliStringFromCoeffs[args___] := (
            Message[GetPauliString::error, "The function GetPauliStringFromCoeffs[] is deprecated. Use GetPauliString[] or temporarily hide this message using Quiet[]."]; 
            GetPauliString[args])
        GetPauliStringFromMatrix[args___] := (
            Message[GetPauliString::error, "The function GetPauliStringFromMatrix[] is deprecated. Use GetPauliString[] or temporarily hide this message using Quiet[]."]; 
            GetPauliString[args])

        MixDamping[qureg_Integer, qb_Integer, prob_Real] := (
            Message[ApplyCircuit::error, "The function MixDamping[] is deprecated, though has still been performed. In future, please use ApplyCircuit[] with the Damp[] gate instead, or temporarily hide this message using Quiet[]."];
            ApplyCircuit[qureg, Subscript[Damp,qb][prob]];
            qureg)
        MixDephasing[qureg_Integer, qb_Integer, prob_Real] := (
            Message[ApplyCircuit::error, "The function MixDephasing[] is deprecated, though has still been performed. In future, please use ApplyCircuit[] with the Deph[] gate instead, or temporarily hide this message using Quiet[]."];
            ApplyCircuit[qureg, Subscript[Deph,qb][prob]];
            qureg)
        MixDepolarising[qureg_Integer, qb_Integer, prob_Real] := (
            Message[ApplyCircuit::error, "The function MixDepolarising[] is deprecated, though has still been performed. In future, please use ApplyCircuit[] with the Depol[] gate instead, or temporarily hide this message using Quiet[]."];
            ApplyCircuit[qureg, Subscript[Depol,qb][prob]];
            qureg)
        MixTwoQubitDephasing[qureg_Integer, qb1_Integer, qb2_Integer, prob_Real] := (
            Message[ApplyCircuit::error, "The function MixTwoQubitDephasing[] is deprecated, though has still been performed. In future, please use ApplyCircuit[] with the Deph[] gate instead, or temporarily hide this message using Quiet[]."];
            ApplyCircuit[qureg, Subscript[Deph,qb1,qb2][prob]];
            qureg)
        MixTwoQubitDepolarising[qureg_Integer, qb1_Integer, qb2_Integer, prob_Real] := (
            Message[ApplyCircuit::error, "The function MixTwoQubitDepolarising[] is deprecated, though has still been performed. In future, please use ApplyCircuit[] with the Depol[] gate instead, or temporarily hide this message using Quiet[]."];
            ApplyCircuit[qureg, Subscript[Depol,qb1,qb2][prob]];
            qureg)
            
        CalcQuregDerivs[circuit_, initQureg_, varVals_, derivQuregs_, workQuregs:_:-1] := (
            Message[ApplyCircuitDerivs::error, "The function CalcQuregDerivs[] is deprecated, though has still been attemptedly performed. In future, please use ApplyCircuitDerivs[], or temporarily hide this message using Quiet[]."];
            ApplyCircuitDerivs[initQureg, circuit, varVals, derivQuregs, workQuregs])
            
        RetargetCircuit[args___] := (
            Message[GetCircuitRetargeted::error, "The function RetargetCircuit[] is deprecated, though has still been attemptedly performed. In future, please use GetCircuitRetargeted[], or temporarily hide this message using Quiet[]."];
            GetCircuitRetargeted[args])


        GetQuregMatrix[args___] := (
            (* temporarily hide the deprecation notice, so existing code doesn't yet need to be updated *)
            (*
                Message[GetQuregState::error, "The deprecated function GetQuregMatrix[] has been automatically replaced with GetQuregState[]. In future, please use GetQuregState[], or temporarily hide this message using Quiet[]."];
            *)
            GetQuregState[args])
           
            
        
        (*
         * global convenience functions
         *)
    
        (* report a generic error that the function was passed with bad args (did not evaluate) *)
        invalidArgError[func_Symbol] := (
            Message[func::error, "Invalid arguments. See ?" <> ToString[func]];
            $Failed)
               
        (* opcodes which correlate with the global IDs in circuits.hpp *)
        getOpCode[gate_] :=
            gate /. {H->0,X->1,Y->2,Z->3,Rx->4,Ry->5,Rz->6,R->7,S->8,T->9,U->10,Deph->11,Depol->12,Damp->13,SWAP->14,M->15,P->16,Kraus->17,G->18,Id->19,Ph->20,KrausNonTP->21,Matr->22,UNonNorm->23,Fac->24,_->-1}
        
        
        
        (*
         * encoding numerical Pauli strings
         *)
         
        pauliCodePatt = Id|X|Y|Z;
        pauliOpPatt = Subscript[pauliCodePatt, _Integer];
        pauliProdPatt = Verbatim[Times][pauliOpPatt..];
        numericCoeffPauliProdPatt = pauliOpPatt | Verbatim[Times][ Repeated[_?Internal`RealValuedNumericQ,{0,1}], pauliOpPatt.. ];

        getNumQubitsInPauliString[expr_] :=
            1 + Max @ Cases[expr, Subscript[pauliCodePatt, q_Integer] :> q, {0,Infinity}]

        isValidNumericPauliString[expr_] := 
            Switch[expr,
                pauliOpPatt, 
                    Last[expr] >= 0,
                numericCoeffPauliProdPatt,
                    With[
                        {qubits = Cases[expr, Subscript[pauliCodePatt, q_Integer] :> q]},
                        And[
                            And @@ (IntegerQ /@ qubits),
                            And @@ NonNegative[qubits],
                            DuplicateFreeQ[qubits]
                        ]
                    ],
                _Plus,
                    AllTrue[expr, isValidNumericPauliString],
                _,
                    False
            ]

        (* X1 *)
        getEncodedNumericPauliString[ Subscript[op:pauliCodePatt, q_Integer] ] := 
            {{1}, {getOpCode@op}, {q}, {1}}
        (* .1 X1 *)
        getEncodedNumericPauliString[ Verbatim[Times][c:_?NumericQ, p:pauliOpPatt.. ] ] := 
            {{N@c}, getOpCode /@ {p}[[All,1]], {p}[[All,2]], {Length@{p}[[All,2]]}}
        (* X1 X2 *)
        getEncodedNumericPauliString[ Verbatim[Times][p:pauliOpPatt.. ] ] :=
            {{1}, getOpCode /@ {p}[[All,1]], {p}[[All,2]], {Length@{p}[[All,2]]}}
        (* .1 X1 X2 *)
        getEncodedNumericPauliString[ p:numericCoeffPauliProdPatt ] :=
            {N@p[[1]], getOpCode /@ Rest[List@@p][[All,1]], Rest[List@@p][[All,2]], Length[p]-1}
        (* .5 X1 X2 + X1 X2 + X1 + .5 X1 *)
        getEncodedNumericPauliString[ s_Plus ] /; AllTrue[List@@s, MatchQ[numericCoeffPauliProdPatt]] :=
            Join @@@ Transpose[getEncodedNumericPauliString /@ (List @@ s)]
        (* 0.` X1 ... *)
        getEncodedNumericPauliString[ s:Verbatim[Plus][ 0.`, numericCoeffPauliProdPatt..] ] :=
            getEncodedNumericPauliString @ s[[2;;]]



        (*
         * recognising symbolic Pauli strings
         *)
         
        symbolicCoeffPauliProdPatt = pauliOpPatt | Verbatim[Times][___, pauliOpPatt, ___];

        isValidSymbolicPauliString[expr_] := 
            Switch[expr,
                pauliOpPatt, 
                    Last[expr] >= 0,
                symbolicCoeffPauliProdPatt,
                    With[
                        {qubits = Cases[expr, Subscript[pauliCodePatt, q_Integer] :> q]},
                        And[
                            And @@ (IntegerQ /@ qubits),
                            And @@ NonNegative[qubits],
                            DuplicateFreeQ[qubits]
                        ]
                    ],
                _Plus,
                    AllTrue[expr, isValidSymbolicPauliString],
                _,
                    False
            ]
        
        
        
        (*
         * encoding circuits
         *)
         
        (* checking a product is a valid operator *)
        SetAttributes[isOperatorFormat, HoldAll]
        isOperatorFormat[op_Times] := isCircuitFormat[ReleaseHold[List @@@ Hold[op]]]
        isOperatorFormat[___] := False
        
        (* convert an operator into a circuit spec without commuting gates *)
        SetAttributes[Circuit, HoldAll]
        SetAttributes[Operator, HoldAll]
        Circuit[gate_?isGateFormat] := 
            {gate}
        Circuit[op_?isOperatorFormat] := 
            ReleaseHold[List @@@ Hold[op]]
        Operator[op_?isGateFormat] :=
            {gate}
        Operator[op_?isOperatorFormat] :=
            Reverse @ Circuit @ op
        
        (* convert MMA matrix to a flat format which can be embedded in the circuit param list *)
        getParamDim[_?VectorQ] := 1
        getParamDim[_?MatrixQ] := 2
        getParamDim[_] := -1
        codifyMatrix[obj_] := Riffle[Re @ N @ Flatten @ obj, Im @ N @ Flatten @ obj]
        codifyMatrixOrVectorWithDim[obj_] :=
            {getParamDim[obj]} ~Join~ codifyMatrix[obj]
            
        (* convert multiple MMA matrices into {#matrices, ... flattened matrices ...} *)
        codifyMatrices[matrs_] :=
            Prepend[Join @@ (codifyMatrix /@ matrs), Length @ matrs]
        
        (* recognising and codifying gates into {opcode, ctrls, targs, params} *)
        gatePatterns = {
            Subscript[C, (ctrls:__Integer)|{ctrls:__Integer}][Subscript[g:U|Matr|UNonNorm,  (targs:__Integer)|{targs:__Integer}][obj:_List]] :> 
                {getOpCode[g], {ctrls}, {targs}, codifyMatrixOrVectorWithDim[obj]},
            Subscript[C, (ctrls:__Integer)|{ctrls:__Integer}][Subscript[gate_Symbol, (targs:__Integer)|{targs:__Integer}][args__]] :> 
                {getOpCode[gate], {ctrls}, {targs}, {args}},
            Subscript[C, (ctrls:__Integer)|{ctrls:__Integer}][Subscript[gate_Symbol, (targs:__Integer)|{targs:__Integer}]] :> 
                {getOpCode[gate], {ctrls}, {targs}, {}},
            Subscript[C, (ctrls:__Integer)|{ctrls:__Integer}][R[param_, ({paulis:pauliOpPatt..}|Verbatim[Times][paulis:pauliOpPatt..]|paulis:pauliOpPatt__)]] :>
                {getOpCode[R], {ctrls}, {paulis}[[All,2]], Join[{param}, getOpCode /@ {paulis}[[All,1]]]},
            R[param_, ({paulis:pauliOpPatt..}|Verbatim[Times][paulis:pauliOpPatt..]|paulis:pauliOpPatt__)] :>
                {getOpCode[R], {}, {paulis}[[All,2]], Join[{param}, getOpCode /@ {paulis}[[All,1]]]},
            Subscript[g:U|Matr|UNonNorm, (targs:__Integer)|{targs:__Integer}][obj_List] :> 
                {getOpCode[g], {}, {targs}, codifyMatrixOrVectorWithDim[obj]},
            Subscript[Kraus, (targs:__Integer)|{targs:__Integer}][matrs_List] :>
                {getOpCode[Kraus], {}, {targs}, codifyMatrices[matrs]},
            Subscript[KrausNonTP, (targs:__Integer)|{targs:__Integer}][matrs_List] :>
                {getOpCode[KrausNonTP], {}, {targs}, codifyMatrices[matrs]},
            Subscript[P, (targs:__Integer)|{targs:__Integer}][outcomes_List] :> 
                {getOpCode[P], {}, {targs}, outcomes},
            Subscript[gate_Symbol, (targs:__Integer)|{targs:__Integer}][args__] :> 
                {getOpCode[gate], {}, {targs}, {args}},
            Subscript[gate_Symbol, (targs:__Integer)|{targs:__Integer}] :> 
                {getOpCode[gate], {}, {targs}, {}},
            G[arg_] :> 
                {getOpCode[G], {}, {}, {arg}},
            Fac[arg_] :>
                {getOpCode[Fac], {}, {}, {Re @ N @ arg, Re @ Im @ arg}}
        };

        (* converting gate sequence to code lists: {opcodes, ctrls, targs, params} *)
        codifyCircuit[circuit_List] :=
            circuit /. gatePatterns // Transpose
        codifyCircuit[circuit_] :=
            codifyCircuit @ {circuit}
            
        (* checking circuit format *)
        isGateFormat[Subscript[_Symbol, (__Integer)|{__Integer}]] := True
        isGateFormat[Subscript[_Symbol, (__Integer)|{__Integer}][__]] := True
        isGateFormat[R[_, (pauliOpPatt|{pauliOpPatt..}|Verbatim[Times][pauliOpPatt..])]] := True
        isGateFormat[(G|Fac)[_]] := True
        isGateFormat[___] := False
        isCircuitFormat[circ_List] := AllTrue[circ,isGateFormat]
        isCircuitFormat[circ_?isGateFormat] := True
        isCircuitFormat[___] := False
        
        unpackEncodedCircuit[codes_List] :=
            Sequence[
                codes[[1]], 
                Flatten @ codes[[2]], Length /@ codes[[2]], 
                Flatten @ codes[[3]], Length /@ codes[[3]],
                Flatten[N /@ codes[[4]]], Length /@ codes[[4]]
            ]

        circContainsDecoherence[circuit_List] :=
            MemberQ[
                circuit, 
                Subscript[ Damp | Deph | Depol | Kraus | KrausNonTP, __ ][__]]
            
        
        
        (*
         * ApplyCircuit[]
         *)
            
        (* declaring optional args to ApplyCircuit *)
        Options[ApplyCircuit] = {
            WithBackup -> True,
            ShowProgress -> False
        };
        
        (* applying a sequence of symoblic gates to a qureg. ApplyCircuitInternal provided by WSTP *)
        applyCircuitInner[qureg_, withBackup_, showProgress:0, circCodes__] :=
            ApplyCircuitInternal[qureg, withBackup, showProgress, circCodes]
        applyCircuitInner[qureg_, withBackup_, showProgress:1, circCodes__] :=
            Monitor[
                (* local private variable, updated by backend *)
                calcProgressVar = 0;
                ApplyCircuitInternal[qureg, withBackup, showProgress, circCodes],
                ProgressIndicator[calcProgressVar]
            ]
        ApplyCircuit[qureg_Integer, {}, OptionsPattern[ApplyCircuit]] :=
            {}
        ApplyCircuit[qureg_Integer, circuit_?isCircuitFormat, OptionsPattern[ApplyCircuit]] :=
            With[
                {codes = codifyCircuit[circuit]},
                Which[
                    MemberQ[codes[[1]], -1],
                    Message[ApplyCircuit::error, "Circuit contained an unrecognised gate: " <> ToString@StandardForm@
                        circuit[[ Position[codes[[1]], -1][[1,1]] ]]]; $Failed,
                    Not @ AllTrue[codes[[4]], Internal`RealValuedNumericQ, 2],
                    Message[ApplyCircuit::error, "Circuit contains non-numerical or non-real parameters!"]; $Failed,
                    Not @ Or[OptionValue[WithBackup] === True, OptionValue[WithBackup] === False],
                    Message[ApplyCircuit::error, "Option WithBackup must be True or False."]; $Failed,
                    Not @ Or[OptionValue[ShowProgress] === True, OptionValue[ShowProgress] === False],
                    Message[ApplyCircuit::error, "Option ShowProgress must be True or False."]; $Failed,
                    True,
                    applyCircuitInner[
                        qureg, 
                        If[OptionValue[WithBackup]===True,1,0], 
                        If[OptionValue[ShowProgress]===True,1,0],
                        unpackEncodedCircuit[codes]
                    ]
                ]
            ]
        (* apply a circuit to get an output state without changing input state. CloneQureg provided by WSTP *)
        ApplyCircuit[inQureg_Integer, circuit_?isCircuitFormat, outQureg_Integer, opts:OptionsPattern[ApplyCircuit]] :=
            Block[{},
                QuEST`CloneQureg[outQureg, inQureg];
                ApplyCircuit[outQureg, circuit, opts]
            ]
        ApplyCircuit[inQureg_Integer, {}, outQureg_Integer, opts:OptionsPattern[ApplyCircuit]] := (
            CloneQureg[outQureg, inQureg];
            {}
        )
        (* warnings for old syntax *)
        ApplyCircuit[((_?isCircuitFormat) | {}), _Integer, OptionsPattern[ApplyCircuit]] := (
            Message[ApplyCircuit::error, "As of v0.8, the arguments have swapped order for consistency. Please now use ApplyCircuit[qureg, circuit]."]; 
            $Failed)
        ApplyCircuit[((_?isCircuitFormat) | {}), _Integer, _Integer, OptionsPattern[ApplyCircuit]] := (
            Message[ApplyCircuit::error, "As of v0.8, the arguments have changed order for consistency. Please now use ApplyCircuit[inQureg, circuit, outQureg]."]; 
            $Failed)
        (* error for bad args *)
        ApplyCircuit[___] := invalidArgError[ApplyCircuit]
        
        
        
        (*
         * encoding circuit derivatives
         *)
        
        encodeDerivParams[Subscript[Rx|Ry|Rz|Ph|Damp|Deph|Depol, __][f_], x_] := {D[f,x]}
        encodeDerivParams[R[f_,_], x_] := {D[f,x]}
        encodeDerivParams[G[f_], x_] := {D[f,x]}
        encodeDerivParams[Fac[f_], x_] := With[{df=D[f,x]}, {Re@N@df, Im@N@df}]
        encodeDerivParams[Subscript[U|Matr|UNonNorm, __][matrOrVec_], x_] := With[
            {dm = D[matrOrVec,x]}, Riffle[Re @ Flatten @ dm, Im @ Flatten @ dm]]
        encodeDerivParams[Subscript[Kraus|KrausNonTP, __][matrs_List], x_] := 
            (Riffle[Re @ Flatten @ #, Im @ Flatten @ #]&) /@ Table[D[m,x] , {m,matrs}]
        encodeDerivParams[Subscript[C, __][g_], x_] := encodeDerivParams[g, x]
        
        encodeDerivCirc[circuit_, varVals_] := Module[{gateInds, varInds, order, encodedCirc, derivParams},

            (* locate the gate indices of the diff variables *)
            gateInds = DeleteDuplicates /@ (Position[circuit, _?(MemberQ[#])][[All, 1]]& /@ varVals[[All,1]]);
            
            (* validate all variables were present in the circuit *)
            If[AnyTrue[gateInds, (# === {} &)],
                Throw @ "One or more variables were not present in the circuit!"];
            
            (* map flat gate indices to relative indices of variables *)
            varInds = Flatten @ Table[ConstantArray[i, Length @ gateInds[[i]]], {i, Length@varVals}];
            gateInds = Flatten @ gateInds;
            
            (* sort info so that gateInds is increasing (for backend optimisations() *)
            order = Ordering[gateInds];
            gateInds = gateInds[[order]];
            varInds = varInds[[order]];
            
            (* encode the circuit for the backend *)
            encodedCirc = codifyCircuit[(circuit /. varVals)];
            
            (* validate that all gates were recognised *)
            If[MemberQ[encodedCirc[[1]], -1],
                Throw["Circuit contained an unrecognised gate: " <> ToString@StandardForm@
                    circuit[[ Position[encodedCirc[[1]], -1][[1,1]] ]]]];
            
            (* validate the circuit contains no unspecified variables *)
            If[Not @ AllTrue[encodedCirc[[4]], Internal`RealValuedNumericQ, 2],
                Throw @ "The circuit contained variables which were not assigned real values."];

            (* differentiate gate args, and pack for backend (without yet making numerical) *)
            derivParams = MapThread[encodeDerivParams, 
                {circuit[[gateInds]], varVals[[varInds,1]]}];
                
            (* validate all gates with diff variables have known derivatives *)
            If[MemberQ[derivParams, encodeDerivParams[_,_]],
                Throw["Cannot differentiate operator " <> 
                    ToString @ StandardForm @ First @ Cases[derivParams, encodeDerivParams[g_,_] :> g] <> "."]];
            
            (* convert packed diff gate args to numerical *)
            derivParams = derivParams /. varVals // N;
            
            (* validate all gate derivatives could be numerically evaluated *)
            If[Not @ AllTrue[Flatten @ derivParams, NumericQ],
                Throw @ "The circuit contained gate derivatives with parameters which could not be numerically evaluated."];
            
            (* return *)
            {encodedCirc, {gateInds, varInds, derivParams}}]
            
        unpackEncodedDerivCircTerms[{gateInds_, varInds_, derivParams_}] :=
            Sequence[gateInds-1, varInds-1, Flatten @ derivParams, Length /@ Flatten /@ derivParams]
            
            
            
        (*
         * derivatives
         *)
         
        ApplyCircuitDerivs[inQureg_Integer, circuit_?isCircuitFormat, vars:{(_ -> _?Internal`RealValuedNumericQ) ..}, outQuregs:{__Integer}, workQuregs:(_Integer|{__Integer}):-1] :=
            Module[
                {ret, encodedCirc, encodedDerivTerms},
                (* check each var corresponds to an out qureg *)
                If[Length[vars] =!= Length[outQuregs],
                    Message[ApplyCircuitDerivs::error, "An equal number of variables and ouptut quregs must be passed."]; Return@$Failed];
                (* encode deriv circuit for backend, throwing any parsing errors *)
                ret = Catch @ encodeDerivCirc[circuit, vars];
                If[Head@ret === String,
                    Message[ApplyCircuitDerivs::error, ret]; Return @ $Failed];
                (* dispatch states, circuit and derivative circuit to backlend *)
                {encodedCirc, encodedDerivTerms} = ret;
                ApplyCircuitDerivsInternal[
                    inQureg, First@{Sequence@@workQuregs}, outQuregs, 
                    unpackEncodedCircuit @ encodedCirc, 
                    unpackEncodedDerivCircTerms @ encodedDerivTerms]]
                    
        ApplyCircuitDerivs[___] := invalidArgError[ApplyCircuitDerivs]  
        
        CalcExpecPauliStringDerivs[initQureg_Integer, circuit_?isCircuitFormat, varVals:{(_ -> _?Internal`RealValuedNumericQ) ..}, paulis_?isValidNumericPauliString, workQuregs:{___Integer}:{}] :=
            Module[
                {ret, encodedCirc, encodedDerivTerms},
                (* encode deriv circuit for backend, throwing any parsing errors *)
                ret = Catch @ encodeDerivCirc[circuit, varVals];
                If[Head@ret === String,
                    Message[CalcExpecPauliStringDerivs::error, ret]; Return @ $Failed];
                (* send to backend, mapping Mathematica indices to C++ indices *)
                {encodedCirc, encodedDerivTerms} = ret;
                CalcExpecPauliStringDerivsInternal[
                    initQureg, workQuregs,
                    unpackEncodedCircuit @ encodedCirc, 
                    unpackEncodedDerivCircTerms @ encodedDerivTerms,
                    Sequence @@ getEncodedNumericPauliString[paulis]]]

        CalcExpecPauliStringDerivs[initQureg_Integer, circuit_?isCircuitFormat, varVals:{(_ -> _?Internal`RealValuedNumericQ) ..}, hamilQureg_Integer, workQuregs:{___Integer}:{}] :=
            Module[
                {ret, encodedCirc, encodedDerivTerms},
                (* encode deriv circuit for backend, throwing any parsing errors *)
                ret = Catch @ encodeDerivCirc[circuit, varVals];
                If[Head@ret === String,
                    Message[CalcExpecPauliStringDerivs::error, ret]; Return @ $Failed];
                (* send to backend, mapping Mathematica indices to C++ indices *)
                {encodedCirc, encodedDerivTerms} = ret;
                CalcExpecPauliStringDerivsDenseHamilInternal[
                    initQureg, hamilQureg, workQuregs,
                    unpackEncodedCircuit @ encodedCirc, 
                    unpackEncodedDerivCircTerms @ encodedDerivTerms]]
            
        CalcExpecPauliStringDerivs[___] := invalidArgError[CalcExpecPauliStringDerivs]
        
        CalcMetricTensor[initQureg_Integer, circuit_?isCircuitFormat, varVals:{(_ -> _?Internal`RealValuedNumericQ) ..}, workQuregs:{___Integer}:{}] :=
            Module[
                {ret, encodedCirc, encodedDerivTerms, retArrs},
                (* encode deriv circuit for backend, throwing any parsing errors *)
                ret = Catch @ encodeDerivCirc[circuit, varVals];
                If[Head@ret === String,
                    Message[CalcMetricTensor::error, ret]; Return @ $Failed];
                (* send to backend, mapping Mathematica indices to C++ indices *)
                {encodedCirc, encodedDerivTerms} = ret;
                data = CalcMetricTensorInternal[
                    initQureg, workQuregs,
                    unpackEncodedCircuit @ encodedCirc, 
                    unpackEncodedDerivCircTerms @ encodedDerivTerms];
                (* reformat output to complex matrix *)
                If[data === $Failed, data, ArrayReshape[
                    MapThread[Complex, {data[[1]], data[[2]]}], 
                    Length[varVals] {1,1}]]]
                    
        CalcMetricTensor[__] := invalidArgError[CalcMetricTensor]
        
        
        
        (*
         * inner products 
         *)
            
        (* compute a matrix of inner products; this can be used in tandem with ApplyCircuitDerivs to populate the Li matrix *)
        CalcInnerProducts[quregIds:{__Integer}] := 
            With[
                {data=CalcInnerProductsMatrixInternal[quregIds],
                len=Length[quregIds]},
                ArrayReshape[
                    MapThread[Complex, {data[[1]], data[[2]]}], 
                    {len, len}
                ]
            ]
        (* computes a vector of inner products <braId|ketIds[i]> *)
        CalcInnerProducts[braId_Integer, ketIds:{__Integer}] := 
            With[
                {data=CalcInnerProductsVectorInternal[braId, ketIds]},
                MapThread[Complex, {data[[1]], data[[2]]}] 
            ]
        (* error for bad args *)
        CalcInnerProducts[___] := invalidArgError[CalcInnerProducts]
            
        (* compute a real symmetric matrix of density inner products *)
        CalcDensityInnerProducts[quregIds:{__Integer}] :=
            ArrayReshape[
                MapThread[
                    Complex,
                    CalcDensityInnerProductsMatrixInternal[quregIds]],
                {Length @ quregIds, Length @ quregIds}
            ]
        (* compute a real vector of density innere products *)
        CalcDensityInnerProducts[rhoId_Integer, omegaIds:{__Integer}] :=
            MapThread[
                Complex,
                CalcDensityInnerProductsVectorInternal[rhoId, omegaIds]]
        (* error for bad args *)
        CalcDensityInnerProducts[___] := invalidArgError[CalcDensityInnerProducts]
        
        
        
        (* 
         * Qureg management 
         *)

        (* destroying a qureg, and clearing the local symbol if recognised *)
        SetAttributes[DestroyQureg, HoldAll];
        DestroyQureg[qureg_Integer] :=
            DestroyQuregInternal[qureg]
        DestroyQureg[qureg_Symbol] :=
            Block[{}, DestroyQuregInternal[ReleaseHold@qureg]; Clear[qureg]]
        DestroyQureg[qureg_] :=
            DestroyQuregInternal @ ReleaseHold @ qureg
        DestroyQureg[___] := invalidArgError[DestroyQureg]

        (* get a local matrix representation of the qureg. GetQuregMatrixInternal provided by WSTP *)
        GetQuregState[qureg_Integer, "ZBasisMatrix"] :=
            With[{data = GetQuregMatrixInternal[qureg]},
                Which[
                    (* if failed, return failure type *)
                    Or[data === $Failed, data === $Aborted],
                        data,
                    (* if state-vector, stitch the real and imag components into a complex array *)
                    data[[2]] === 0,
                        MapThread[#1 + I #2 &, {data[[3]], data[[4]]}],
                    (* if density-matrix, stitch the real and imag components into a complex matrix *)
                    data[[2]] === 1,
                        Transpose @ ArrayReshape[
                            MapThread[#1 + I #2 &, {data[[3]], data[[4]]}], 
                            {2^data[[1]],2^data[[1]]}]
                ]
            ]

        GetQuregState[qureg_Integer, "ZBasisKets"] := 
            With[
                {matr = GetQuregState[qureg, "ZBasisMatrix"]},
                {nQb = Log2 @ Length @ matr},
                Which[
                    (* if failed, return failure type *)
                    Or[data === $Failed, data === $Aborted],
                        data,
                    (* project state-vector into kets *)
                    Length @ Dimensions @ matr === 1,
                        matr . Table[
                            Ket @ IntegerString[i, 2, nQb], {i, 0, 2^nQb - 1}],
                    (* project density-matrix into ket-bra's *)
                    Length @ Dimensions @ matr === 2,
                        Flatten[matr] . Flatten @ Table[
                            Ket @ IntegerString[i, 2, nQb] ** 
                            Bra @ IntegerString[j, 2, nQb],
                            {i, 0, 2^nQb - 1}, {j, 0, 2^nQb - 1}]
                (* tidy up some amplitudes for visual clarity *)
                ] /. {
                        Complex[1.`,0.`] -> 1, (* (1.`+0.`) |s> -> |s> *)
                        Complex[0.`,0.`] -> 0, (* (0.`+0.`) |s> -> 0 *)
                        Complex[x_,0.`] -> x   (* (x + 0.`) |s> -> x |s> *)
                    }
            ]

        GetQuregState[qureg_Integer] :=
            GetQuregState[qureg, "ZBasisMatrix"]

        GetQuregState[___] := invalidArgError[GetQuregState]

        (* overwrite the state of a qureg. InitStateFromAmps provided by WSTP *)
        SetQuregMatrix[qureg_Integer, elems_List] :=
            With[{flatelems = N @ 
                Which[
                    (* vectors in various forms *)
                    Length @ Dimensions @ elems === 1,
                        elems,
                    First @ Dimensions @ elems === 1,
                        First @ elems,
                    (Dimensions @ elems)[[2]] === 1,
                        First @ Transpose @ elems,
                    (* density matrices *)
                    SquareMatrixQ @ elems,
                        Flatten @ Transpose @ elems
                ]},
                QuEST`InitStateFromAmps[qureg, Re[flatelems], Im[flatelems]]
            ]
        SetQuregMatrix[___] := invalidArgError[SetQuregMatrix]
        
        SetQuregToPauliString[qureg_Integer, hamil_?isValidNumericPauliString] :=
            SetQuregToPauliStringInternal[qureg, Sequence @@ getEncodedNumericPauliString[hamil]]
        SetQuregToPauliString[___] := invalidArgError[SetQuregToPauliString]
        

        
        (*
         * Numeric Pauli strings
         *)

        invalidPauliScalarError[caller_] := (
            Message[caller::error, "The Pauli string contains a scalar. Perhaps you meant to multiply it onto an identity (Id) operator."]; 
            $Failed)
            

        CalcExpecPauliString[qureg_Integer, paulis_?isValidNumericPauliString, workspace_Integer] :=
            CalcExpecPauliStringInternal[qureg, workspace, Sequence @@ getEncodedNumericPauliString[paulis]]
        CalcExpecPauliString[_Integer, Verbatim[Plus][_?NumericQ, ___], _Integer] := 
            invalidPauliScalarError[CalcExpecPauliString]
        CalcExpecPauliString[___] := invalidArgError[CalcExpecPauliString]


        ApplyPauliString[inQureg_Integer, paulis_?isValidNumericPauliString, outQureg_Integer] :=
            ApplyPauliStringInternal[inQureg, outQureg, Sequence @@ getEncodedNumericPauliString[paulis]]
        ApplyPauliString[_Integer, Verbatim[Plus][_?NumericQ, ___], _Integer] := 
            invalidPauliScalarError[ApplyPauliString]
        ApplyPauliString[___] := invalidArgError[ApplyPauliString]


        CalcPauliStringMinEigVal[paulis_?isValidNumericPauliString, MaxIterations -> its_Integer] := With[
            {matr = CalcPauliExpressionMatrix[paulis]},
            - First @ Eigenvalues[- matr, 1, Method -> {"Arnoldi", MaxIterations -> its, "Criteria" -> "RealPart"}]]
        CalcPauliStringMinEigVal[paulis_?isValidNumericPauliString] :=
            CalcPauliStringMinEigVal[paulis, MaxIterations -> 10^5]
        CalcPauliStringMinEigVal[___] := invalidArgError[CalcPauliStringMinEigVal]
        

        CalcPauliStringMatrix[paulis_?isValidNumericPauliString] := With[
            {pauliCodes = getEncodedNumericPauliString[paulis]},
            {elems = CalcPauliStringMatrixInternal[1+Max@pauliCodes[[3]], Sequence @@ pauliCodes]},
            If[elems === $Failed, elems, 
                (#[[1]] + I #[[2]])& /@ Partition[elems,2] // Transpose]]
        CalcPauliStringMatrix[Verbatim[Plus][_?NumericQ, ___]] :=
            invalidPauliScalarError[CalcPauliStringMatrix]
        CalcPauliStringMatrix[___] := invalidArgError[CalcPauliStringMatrix]
        


        (*
         * Symbolic Pauli strings
         *)


        getFullHilbertPauliMatrix[numQ_][Subscript[s_,q_]] := Module[
            {m=ConstantArray[SparseArray @ IdentityMatrix[2], numQ]},
            m[[q+1]] = SparseArray @ PauliMatrix[s /. {Id->0, X->1,Y->2,Z->3}];
            If[Length[m]>1, KroneckerProduct @@ (Reverse @ m), First @ m]]
            
        SetAttributes[CalcPauliExpressionMatrix, HoldAll]
        CalcPauliExpressionMatrix[h_, nQb_] := With[
            {hFlat = SimplifyPaulis[h]},
            ReleaseHold[
                HoldForm[hFlat] /. Verbatim[Times][a___, b:pauliOpPatt, c___] :>
                    RuleCondition @ Times[
                        Sequence @@ Cases[{a,b,c}, Except[pauliOpPatt]],
                        Dot @@ getFullHilbertPauliMatrix[nQb] /@ Cases[{a,b,c}, pauliOpPatt]
                    ] /. p:pauliOpPatt :> RuleCondition @ getFullHilbertPauliMatrix[nQb][p]]]
        CalcPauliExpressionMatrix[h_] := With[
            {hFlat = SimplifyPaulis[h]},
            {nQb = Max[1 + Cases[{hFlat}, Subscript[(Id|X|Y|Z), q_]:>q, Infinity]]},
            CalcPauliExpressionMatrix[hFlat, nQb]]
        CalcPauliExpressionMatrix[___] := invalidArgError[CalcPauliExpressionMatrix]


        GetPauliStringOverlap[a_?isValidSymbolicPauliString, b_?isValidSymbolicPauliString] :=
            Module[
                {aInds,bInds, aAssoc,bAssoc, overlap},
                {aInds, bInds} = GetPauliStringReformatted[#, "Index"]& /@ {a,b};

                (* handle when a (or b) was a single unweighted product *)
                If[Head[aInds] === Integer, aInds = {{aInds,1}}];
                If[Head[bInds] === Integer, bInds = {{bInds,1}}];

                (* pre-sum duplicated terms in each string *)
                aAssoc = Merge[Rule @@@ aInds, Total];
                bAssoc = Merge[Rule @@@ bInds, Total];

                (* conj-multiply common strings between each list *)
                overlap = Merge[KeyIntersection @ {aAssoc, bAssoc}, #[[2]] Conjugate @ #[[1]] &];

                (* and return the result as a Pauli string *)
                Total @ KeyValueMap[#2 GetPauliString @ #1 &, overlap]
            ]
        GetPauliStringOverlap[___] := invalidArgError[GetPauliStringOverlap]


        GetRandomPauliString[
            numQubits_Integer?Positive, numTerms:(_Integer?Positive|Automatic|All):Automatic, 
            {minCoeff_?Internal`RealValuedNumericQ, maxCoeff_?Internal`RealValuedNumericQ}
        ] := With[
            {numUniqueTensors = 4^numQubits},
            (* give warning if too many terms requested *)
            If[ NumericQ[numTerms] && numTerms > numUniqueTensors,
                Message[GetRandomPauliString::error, "More terms were requested than there are unique Pauli tensors. Hide this warning with Quiet[]."]]; 
            With[
                {strings = Table[
                    (* generate uniformly random coefficients *)
                    RandomReal[{minCoeff,maxCoeff}] * 
                    Times @@ (
                        (* generate uniformly random but unique Pauli tensors *)
                        MapThread[Subscript, {
                            IntegerDigits[tensorInd, 4, numQubits] /. {0->Id,1->X,2->Y,3->Z},
                            Range[0,numQubits-1]}
                            ] /. Subscript[Id, _]->Nothing /. {} -> {Subscript[Id, 0]}),
                        {tensorInd, RandomSample[0;;(numUniqueTensors-1), 
                    (* potentially override the number of terms/tensors *)
                    Min[numTerms /. {Automatic -> 4 numQubits^4, All -> numUniqueTensors}, numUniqueTensors]]}]},
                (* append an Id with max target qubits on the ened for user convenience, if not already a max target  *)
                Plus @@ If[
                    FreeQ[ Last @ strings, Subscript[_Symbol, numQubits-1]],
                    Append[Most @ strings, (Last @ strings) Subscript[Id,numQubits-1]],
                    strings]]]
        GetRandomPauliString[numQubits_Integer?Positive, numTerms:(_Integer?Positive|Automatic|All):Automatic] :=
            GetRandomPauliString[numQubits, numTerms, {-1,1}]
        GetRandomPauliString[___] := invalidArgError[GetRandomPauliString]



        (*
         * Augmenting Pauli strings
         *)

        GetPauliStringRetargeted[str_?isValidSymbolicPauliString, map_] := 
            Enclose[
                ReplaceAll[str, Subscript[p:pauliCodePatt, q_] :> Subscript[p, q /. map]] // ConfirmQuiet,
                Function[{failObj},
                    Message[GetPauliStringRetargeted::error, "Invalid rules caused the below ReplaceAll error:"]; 
                    ReleaseHold @ failObj @ "HeldMessageCall";
                    $Failed]]

        GetPauliStringRetargeted[___] := invalidArgError[GetPauliStringRetargeted]



        (*
         * Creating Pauli strings from other structures
         *)


        optionalNumQbPatt = _Integer?Positive|PatternSequence[];

        getPauliStringFromAddress[addr_String, removeIds_:True] :=
            Enclose[
                ConfirmQuiet[
                    Plus @@ (#[[1]] If[ 
                            AllTrue[ #[[2;;]], PossibleZeroQ ],
                            If[removeIds,
                                Subscript[Id, 0],
                                Product[Subscript[Id,q], {q,0,Length@#-2}]
                            ],
                            Times @@ MapThread[
                            (   Subscript[Switch[#2, 0, Id, 1, X, 2, Y, 3, Z], #1 - 1] /. 
                                If[removeIds, Subscript[Id, _] ->  Sequence[], {}] & ), 
                                {Range @ Length @ #[[2 ;;]], #[[2 ;;]]}
                            ]
                        ] &) /@ ReadList[addr, Number, RecordLists -> True]],
                Function[{failObj},
                    Message[GetPauliString::error, "Parsing the file failed due to the below error:"];
                    ReleaseHold @ failObj @ "HeldMessageCall";
                    $Failed]]

        getPauliStringFromAddress[addr_String, numQb_Integer, removeIds:True] :=
            getPauliStringFromAddress[addr, removeIds]

        getPauliStringFromAddress[addr_String, numQbOut_Integer, removeIds:False] := With[
            {pauliStr = Check[getPauliStringFromAddress[addr, removeIds], Return @ $Failed]},
            {strNumQb = getNumQubitsInPauliString[pauliStr]},
            If[ numQbOut < strNumQb,
                Message[GetPauliString::error, 
                    "The specified number of qubits (" <> ToString[numQbOut] <> ") was fewer than that " <>
                    "encoded in the file (" <> ToString[strNumQb] <> ")."];
                Return @ $Failed];
            If[numQbOut === strNumQb,
                Return @ pauliStr];
            Expand[ Product[Subscript[Id,q], {q,strNumQb,numQbOut-1}] * pauliStr ]
        ]


        getNthPauliTensor[n_, numQubits_] :=
            PadLeft[IntegerDigits[n,4], numQubits, 0]
            
        getNthPauliTensorMatrix[n_, 1] /; n < 4 :=
            PauliMatrix[n]
        getNthPauliTensorMatrix[n_, numQubits_] /; n < 4^numQubits :=
            KroneckerProduct @@ PauliMatrix /@ getNthPauliTensor[n, numQubits]
            
        getNthPauliTensorSymbols[0, numQubits_, removeIds_:True] :=
            If[removeIds,
                Subscript[Id, numQubits-1],
                Times @@ (Subscript[Id, #]& /@ Range[0,numQubits-1])
            ]
        getNthPauliTensorSymbols[n_, numQubits_, removeIds_:True] :=
            Times @@ (MapThread[Subscript, {
                getNthPauliTensor[n, numQubits] /. {0->Id,1->X,2->Y,3->Z}, 
                Reverse @ Range[numQubits] - 1}] /. If[removeIds, Subscript[Id, _] -> Nothing, {}])

        isPowerOfTwoSquareMatrix[m_] := 
            And[SquareMatrixQ @ m, BitAnd[Length@m, Length@m - 1] === 0]

        getPauliStringFromMatrix[m_?isPowerOfTwoSquareMatrix, removeIds_:True] := 
            getPauliStringFromMatrix[m, Log2 @ Length @ m, removeIds]

        getPauliStringFromMatrix[m_?isPowerOfTwoSquareMatrix, nQbOut_Integer, removeIds_:True] := Module[
            {nQbMatr, coeffs},
            nQbMatr = Log2 @ Length @ m;
            If[nQbOut < nQbMatr,
                Message[GetPauliString::error, 
                    "The specified number of qubits (" <> ToString[nQbOut] <> ") was fewer than that " <>
                    "suggested (" <> ToString[nQbMatr] <> ") by the matrix's dimension."];
                Return @ $Failed];
            coeffs =  1/2^nQbMatr Table[
                Tr[getNthPauliTensorMatrix[i,nQbMatr] . m],  
                {i, 0, 4^nQbMatr - 1}];
            coeffs . Table[getNthPauliTensorSymbols[n,nQbOut,removeIds], {n, 0, 4^nQbMatr-1}]]

        getPauliStringFromMatrix[___] := (
            Message[GetPauliString::error, "Matrix must be square with a power-of-2 number of rows and columns."];
            $Failed)
        

        getPauliStringFromIndex[ind_Integer, removeIds_:True] :=
            getPauliStringFromIndex[ind, If[ind <= 0, 1, 1 + Floor[Log[4, ind]]], removeIds]

        getPauliStringFromIndex[ind_Integer, numPaulis_Integer, removeIds_:True] := With[
            {maxInd = 4^numPaulis - 1},

            If[ind < 0,
                Message[GetPauliString::error, "Index must be positive or zero."];
                Return @ $Failed];

            If[ind > maxInd, 
                Message[GetPauliString::error, 
                    "The given index (" <> ToString[ind] <> ") exceeds the maximum possible (" <> 
                    ToString[maxInd] <> " = 4^" <> ToString[numPaulis] <> "-1) for the given " <>
                    "number of Pauli operators (" <> ToString[numPaulis] <> ")."]; 
                Return @ $Failed];

            getNthPauliTensorSymbols[ind, numPaulis, removeIds]
        ]


        getPauliStringFromDigits[digits_List, nQb:optionalNumQbPatt, removeIds_:True] :=
            If[
                And[ And @@ GreaterEqualThan[0] /@ digits, And @@ LessThan[4] /@ digits ],
                getPauliStringFromIndex[FromDigits[digits, 4], nQb, removeIds],
                Message[GetPauliString::error, "Each individual digit must be one of 0 (denoting Id), 1 (X), 2 (Y) or 3 (Z)."];
                $Failed
            ]


        Options[GetPauliString] = {
            "RemoveIds" -> Automatic
        }

        (* decide whether to automatically remove Ids from returned product (i.e. whether numPaulis was specified) *)
        shouldRemovePauliStringIds[opts:OptionsPattern[GetPauliString]] :=
            OptionValue["RemoveIds"] /. Automatic->True
        shouldRemovePauliStringIds[numPaulis_Integer, opts:OptionsPattern[GetPauliString]] :=
            OptionValue["RemoveIds"] /. Automatic->False

        (* catching a specific invalid empty-target list case, which Mathematica otherwise accepts as a valid option list *)
        GetPauliString[_String|_?MatrixQ|_Integer, OrderlessPatternSequence[{}, nQb:optionalNumQbPatt], opts___] := (
            Message[GetPauliString::error, "Optional list of target qubits must not be empty."];
            $Failed)

        (* accept files, matrices or basis indices, and an optional numPaulis specifier *)
        GetPauliString[address_String, numPaulis:optionalNumQbPatt, opts:OptionsPattern[]] :=
            getPauliStringFromAddress[address, numPaulis, shouldRemovePauliStringIds[numPaulis, opts]]

        GetPauliString[matrix_?MatrixQ, numPaulis:optionalNumQbPatt, opts:OptionsPattern[]] :=
            getPauliStringFromMatrix[matrix, numPaulis, shouldRemovePauliStringIds[numPaulis, opts]]

        GetPauliString[index_Integer, numPaulis:optionalNumQbPatt, opts:OptionsPattern[]] :=
            getPauliStringFromIndex[index, numPaulis, shouldRemovePauliStringIds[numPaulis, opts]]

        GetPauliString[{digits__Integer}, numPaulis:optionalNumQbPatt, opts:OptionsPattern[]] :=
            If[ Length@{numPaulis}===1 && numPaulis<Length@{digits},
                Message[GetPauliString::error, "The overriden number of qubits was fewer than the number of given digits."];
                    Return @ $Failed,
                getPauliStringFromDigits[{digits}, numPaulis, shouldRemovePauliStringIds[numPaulis, opts]]]

        (* optionally remap the returned Pauli string to a custom set of targets *)
        GetPauliString[obj:(_String|_?MatrixQ|_Integer|{__Integer}), OrderlessPatternSequence[targs:{___Integer}, numPaulis:optionalNumQbPatt], opts:OptionsPattern[]] :=
            Module[
                {pauliStr, map, retargStr, numQbInStr, remIds, untargs, padIds},

                (* validate options, and choose whether to remove Ids *)
                remIds = Check[OptionValue @ "RemoveIds", Return @ $Failed] /. Automatic -> False;

                (* partially validate targs *)
                If[ Not @ AllTrue[targs, NonNegative] || Not @ DuplicateFreeQ[targs],
                    Message[GetPauliString::error, "Target qubits must be list of unique, non-negative and integers."];
                    Return @ $Failed];

                (* produce Pauli string with indices from 0, every term is Length[targs]-operators. *)
                pauliStr = Check[GetPauliString[obj, Length[targs], "RemoveIds"->False], Return @ $Failed];

                (* modify the Pauli string to the users target qubits; may contain Ids, but is NOT necessarily full-length. E.g. X7 Id5 Z3 *)
                map = MapThread[Rule, {Range @ Length @ targs -1, targs}];
                retargStr = GetPauliStringRetargeted[pauliStr, map];

                (* validate optional forced numPaulis equals or exceeds num in retargStr *)
                numQbInStr = 1 + Max[targs];
                If[Length@{numPaulis}>0 && numPaulis < numQbInStr,
                    Message[GetPauliString::error, 
                        "The requested number of Pauli operators (" <> ToString[numPaulis] <> ") cannot be fewer than " <>
                        "the number in the targeted Pauli string (" <> ToString[numQbInStr] <> ")."];
                    Return @ $Failed];

                (* if numPaulis specified, add additional Ids at all untargeted *)
                If[Length@{numPaulis}>0 && (numPaulis>Length[targs]) && Not[remIds],
                    untargs = Complement[Range@numPaulis-1, targs];
                    padIds = Product[Subscript[Id,t], {t,untargs}];
                    retargStr = Expand[padIds * retargStr, pauliOpPatt]];

                (* optionally remove Ids, but keep standalone Id terms  *)
                If[remIds, retargStr = retargStr //.
                    Verbatim[Times][OrderlessPatternSequence[c___, p:pauliOpPatt, Subscript[Id,_]]] :> c p];

                (* return *)
                retargStr
            ]

        GetPauliString[___] := invalidArgError[GetPauliString]



        (*
         * Converting Pauli strings between formats
         *)
        
        separatePauliStringIntoProdsAndCoeffs[pauli:pauliOpPatt] :=
            {{pauli, 1}}

        separatePauliStringIntoProdsAndCoeffs[prod:Verbatim[Times][___, pauliOpPatt, ___]] :=
            {{
                Times @@ Cases[prod, pauliOpPatt],
                Times @@ Cases[prod, Except @ pauliOpPatt]
            }}

        separatePauliStringIntoProdsAndCoeffs[sum_Plus] :=
            Join @@ (separatePauliStringIntoProdsAndCoeffs /@ List @@ sum)


        getIndexOfPauliString[ Subscript[s:pauliCodePatt, q_Integer?NonNegative] ] :=
            (s /. {Id->0,X->1,Y->2,Z->3}) * 4^q

        getIndexOfPauliString[ prod:pauliProdPatt?isValidSymbolicPauliString ] :=
            Total[getIndexOfPauliString /@ List @@ prod]

        getIndexOfPauliString[ string_?isValidSymbolicPauliString ] := 
            MapAt[getIndexOfPauliString, separatePauliStringIntoProdsAndCoeffs[string], {All, 1}]


        getDigitsOfPauliString[ prod:(pauliOpPatt|pauliProdPatt)?isValidSymbolicPauliString, numQubits_  ] :=
            getNthPauliTensor[getIndexOfPauliString @ prod, numQubits];

        getDigitsOfPauliString[ string_?isValidSymbolicPauliString, numQubits_  ] := 
            MapAt[getDigitsOfPauliString[#,numQubits]&, separatePauliStringIntoProdsAndCoeffs[string], {All, 1}]

        getDigitsOfPauliString[ string_?isValidSymbolicPauliString ] :=
            getDigitsOfPauliString[string, getNumQubitsInPauliString @ string]


        getKroneckerFormOfPauliString[ prod:(pauliOpPatt|pauliProdPatt)?isValidSymbolicPauliString, numQubits_ ] :=
            CircleTimes @@ {Id,X,Y,Z}[[ getDigitsOfPauliString[prod,numQubits] + 1 ]]

        getKroneckerFormOfPauliString[ string_?isValidSymbolicPauliString, numQubits_ ] := 
            With[
                {prods = separatePauliStringIntoProdsAndCoeffs[string]},
                MapAt[(getKroneckerFormOfPauliString[#,numQubits]&), prods, {All, 1}]]

        getKroneckerFormOfPauliString[ string_?isValidSymbolicPauliString ] :=
            getKroneckerFormOfPauliString[string, getNumQubitsInPauliString @ string]


        getCompactStringFormOfPauliString[ prod:(pauliOpPatt|pauliProdPatt)?isValidSymbolicPauliString, numQubits_ ] :=
            With[
                {kron = Check[getKroneckerFormOfPauliString[prod, numQubits], Return[$Failed,With]]},
                StringReplace[StringJoin @@ ToString /@ kron, "Id" -> "I"]]

        getCompactStringFormOfPauliString[ string_?isValidSymbolicPauliString, numQubits_ ] :=
            With[
                {prods = separatePauliStringIntoProdsAndCoeffs[string]},
                MapAt[(getCompactStringFormOfPauliString[#,numQubits]&), prods, {All, 1}]]
        
        getCompactStringFormOfPauliString[ string_?isValidSymbolicPauliString ] :=
            getCompactStringFormOfPauliString[string, getNumQubitsInPauliString @ string]


        GetPauliStringReformatted[ string_?isValidSymbolicPauliString, OrderlessPatternSequence[numQubits_Integer?Positive, _String|PatternSequence[]] ] /; 
            (getNumQubitsInPauliString[string] > numQubits) := (
                Message[GetPauliStringReformatted::error, "The given Pauli string targeted a larger index qubit than the number of qubits specified."]; 
                Return @ $Failed)

        GetPauliStringReformatted[ string_?isValidSymbolicPauliString, OrderlessPatternSequence[nQb:optionalNumQbPatt, "Index"] ] :=
            getIndexOfPauliString[string]  (* nQb isn't used but it's still passable for user convenience *)

        GetPauliStringReformatted[ string_?isValidSymbolicPauliString, OrderlessPatternSequence[nQb:optionalNumQbPatt, "Digits"] ] :=
            getDigitsOfPauliString[string, nQb]

        GetPauliStringReformatted[ string_?isValidSymbolicPauliString, OrderlessPatternSequence[nQb:optionalNumQbPatt, "Kronecker"] ] :=
            getKroneckerFormOfPauliString[string, nQb]

        GetPauliStringReformatted[ string_?isValidSymbolicPauliString, OrderlessPatternSequence[nQb:optionalNumQbPatt, "String"] ] :=
            getCompactStringFormOfPauliString[string, nQb]
        
        GetPauliStringReformatted[___] := invalidArgError[GetPauliStringReformatted]
            

        
        (*
         * Analytic and numerical channel decompositions for statevector simulation
         *)
         
        convertOpToPureCircs[Subscript[(Kraus|KrausNonTP), q__][matrs:{ __?MatrixQ }]] := 
            Circuit /@ Subscript[Matr, q] /@ matrs
        convertOpToPureCircs[Subscript[Deph, q_][x_]] := {
            Circuit[ Fac@Sqrt[1-x] ],
            Circuit[ Fac@Sqrt[x] Subscript[Z, q] ] }
        convertOpToPureCircs[Subscript[Deph, q1_,q2_][x_]] := {
            Circuit[ Fac@Sqrt[1-x] ],
            Circuit[ Fac@Sqrt[x/3] Subscript[Z, q1] ],
            Circuit[ Fac@Sqrt[x/3] Subscript[Z, q2] ],
            Circuit[ Fac@Sqrt[x/3] Subscript[Z, q1] Subscript[Z, q2] ]}
        convertOpToPureCircs[Subscript[Depol, q_][x_]] := {
            Circuit[ Fac@Sqrt[1-x] ],
            Circuit[ Fac@Sqrt[x/3] Subscript[X, q] ],
            Circuit[ Fac@Sqrt[x/3] Subscript[Y, q] ],
            Circuit[ Fac@Sqrt[x/3] Subscript[Z, q] ]}
        convertOpToPureCircs[Subscript[Depol, q1_,q2_][x_]] := 
            Join[{{Fac@Sqrt[1-x]}}, Rest @ Flatten[
                Table[{Fac@Sqrt[x/15], Subscript[a, q1], Subscript[b, q2]}, {a,{Id,X,Y,Z}}, {b,{Id,X,Y,Z}}] /. Subscript[Id, _] -> Nothing, 1]]
        convertOpToPureCircs[g:Subscript[Damp, q_][x_]] :=
            convertOpToPureCircs @ First @ GetCircuitGeneralised @ g
        convertOpToPureCircs[g_] :=
            {{g}} (* non-decoherence ops have no alternatives *)
            
        GetCircuitsFromChannel[circ_List /; isCircuitFormat[circ] ] := With[
            {choices = convertOpToPureCircs /@ circ},
            {numCircs = Times @@ Length /@ choices},
            If[Ceiling @ Log2[numCircs] > $SystemWordLength,
                Message[GetCircuitsFromChannel::error, "The number of unique circuit decompositions exceeds 2^$SystemWordLength and cannot be enumerated."]; $Failed,
                   Flatten /@ Tuples[choices]]]
        GetCircuitsFromChannel[gate_?isCircuitFormat] :=
            GetCircuitsFromChannel @ {gate}
        GetCircuitsFromChannel[___] := invalidArgError[GetCircuitsFromChannel]
        

        GetRandomCircuitFromChannel[ channel_List /; isCircuitFormat[channel] ] := Module[
            {circs, probs},

            (* validate mixed-channel probabilities are valid (so max-prob is maximally mixed) *)
            If[MemberQ[channel, 
                Subscript[Damp, _][x_ /; x < 0 || x > 1] |
                Subscript[Deph, _][x_ /; x < 0 || x > 1/2] |
                Subscript[Deph, _, _][x_ /; x < 0 || x > 3/4] |
                Subscript[Depol, _][x_ /; x < 0 || x > 3/4] |
                Subscript[Depol, _, _][x_ /; x < 0 || x > 15/16]],
                Message[GetRandomCircuitFromChannel::error, "A unitary-mixture channel had an invalid probability which was negative or exceeded that causing maximal mixing."];
                Return[$Failed]];

            (* get circuit decompositions of each operator *)
            circs = convertOpToPureCircs /@ channel;
            
            (* infer the probabilities from Fac[] in mixed-unitary noise, and assert other noise decompositions are uniform *)
            probs = Table[
                Times @@ (Cases[choice, Fac[x_]:>Abs[x]^2] /. {}->{1/N@Length@choices}), 
                {choices, circs}, {choice, choices}];
            
            (* validate probabilities *)
            If[ Not[And @@ Table[
                VectorQ[probset, Internal`RealValuedNumericQ] &&
                AllTrue[probset, (0 <= # <= 1&)] &&
                Abs[Total[probset] - 1] < 10^6 $MachineEpsilon, 
                {probset, probs}]],
                    Message[GetRandomCircuitFromChannel::error, "The probabilities of a decomposition of a decoherence operator were invalid and/or unnormalised."];
                    Return[$Failed]];

            (* randomly select a pure circuit from each channel decomposition *)
            Flatten @ MapThread[
                With[{choice=RandomChoice[#1 -> #2]}, 
                    (* we must multiply the matrices of incoherent noise with the asserted uniform probability *)
                    If[ Length[#1]>1 && Not @ MemberQ[choice, Fac[_]],
                        (* which we can equivalently perform with a Fac gate *)
                        Join[{Fac[Sqrt@N@Length[#1]], choice}],
                        choice /. Fac[_]->Nothing]] &,
                {probs, circs}]
        ]

        GetRandomCircuitFromChannel[operator_?isCircuitFormat] :=
            GetRandomCircuitFromChannel @ {operator}

        GetRandomCircuitFromChannel[___] := invalidArgError[GetRandomCircuitFromChannel]
        

        Options[SampleExpecPauliString] = {
            ShowProgress -> False
        };
        
        sampleExpecPauliStringInner[True, args__] :=
            Monitor[
                (* local private variable, updated by backend *)
                calcProgressVar = 0;
                SampleExpecPauliStringInternal[1, args],
                ProgressIndicator[calcProgressVar]]
        sampleExpecPauliStringInner[False, args__] :=
            SampleExpecPauliStringInternal[0, args]
         
        SampleExpecPauliString[qureg_Integer, channel_?isCircuitFormat, paulis_?isValidNumericPauliString, numSamples:(_Integer|All), {work1_Integer, work2_Integer}, OptionsPattern[]] /; (work1 === work2 === -1 || And[work1 =!= -1, work2 =!= -1]) :=
            If[numSamples =!= All && numSamples >= 2^63, 
                Message[SampleExpecPauliString::error, "The requested number of samples is too large, and exceeds the maximum C long integer (2^63)."]; $Failed,
                With[{codes = codifyCircuit[channel]},
                    If[
                        Not @ AllTrue[codes[[4]], Internal`RealValuedNumericQ, 2],
                        Message[SampleExpecPauliString::error, "Circuit contains non-numerical or non-real parameters!"]; $Failed,
                        sampleExpecPauliStringInner[
                            OptionValue[ShowProgress],
                            qureg, work1, work2, numSamples /. (All -> -1),
                            unpackEncodedCircuit[codes],
                            Sequence @@ getEncodedNumericPauliString[paulis]]]]]
        
        SampleExpecPauliString[qureg_Integer, channel_?isCircuitFormat, paulis_?isValidNumericPauliString, numSamples:(_Integer|All), opts:OptionsPattern[]] :=
            SampleExpecPauliString[qureg, channel, paulis, numSamples, {-1, -1}, opts]
        
        SampleExpecPauliString[___] := invalidArgError[SampleExpecPauliString]


        SampleClassicalShadow[qureg_Integer, numSamples_Integer] /; (numSamples >= 2^63) := (
            Message[SampleClassicalShadow::error, "The requested number of samples is too large, and exceeds the maximum C long integer (2^63)."];
            $Failed)
        SampleClassicalShadow[qureg_Integer, numSamples_Integer] := 
            With[
                {data = SampleClassicalShadowStateInternal[qureg, numSamples]},
                If[data === $Failed, data, 
                    Transpose[{
                        Partition[ data[[2]], data[[1]]],
                        Partition[ data[[3]], data[[1]]]}]]]
        SampleClassicalShadow[___] := invalidArgError[SampleClassicalShadow]


        CalcExpecPauliProdsFromClassicalShadow[shadow_List, prods:{__:numericCoeffPauliProdPatt}, numBatches_Integer:10] := 
            If[
                Not @ MatchQ[Dimensions[shadow], {nSamps_, 2, nQb_}],
                (Message[CalcExpecPauliProdsFromClassicalShadow::error, "The classical shadow input must be a list " <>
                    "(length equal to the number of samples) of length-2 sublists, each of length equal to the number 
                    of qubits. This is the format {{{bases,outcomes}},...}, matching that output by SampleClassicalShadow[]."];
                    $Failed),
                With[
                    {ops = (List @@@ prods) /. {p_:pauliCodePatt, q_Integer} :> {Subscript[p, q]}},
                    {numQb = Length @ First @ First @ shadow,
                     prodPaulis = ops[[All, All, 1]] /. {X->1,Y->2,Z->3},
                     prodQubits = ops[[All, All, 2]]},
                    CalcExpecPauliProdsFromClassicalShadowInternal[
                        numQb, numBatches, Length[shadow], Flatten @ shadow[[All,1]], Flatten @ shadow[[All,2]],
                        Flatten @ prodPaulis, Flatten @ prodQubits, Length /@ prodPaulis]
                ]
            ]    
         CalcExpecPauliProdsFromClassicalShadow[___] := invalidArgError[CalcExpecPauliProdsFromClassicalShadow]

    
        
        (*
         * QuESTEnv management 
         *)
        
        getIgorLink[id_] :=
            LinkConnect[
                With[{host="@129.67.85.74",startport=50000},
                ToString[startport+id] <> host <> "," <> ToString[startport+id+100] <> host],
                LinkProtocol->"TCPIP"]
                
        getRemoteLink[ip_, port1_, port2_] :=
            LinkConnect[
                With[{host="@"<>ip},
                ToString[port1] <> host <> "," <> ToString[port2] <> host],
                LinkProtocol->"TCPIP"]
                    
        CreateRemoteQuESTEnv[ip_String, port1_Integer, port2_Integer] := Install @ getRemoteLink[ip, port1, port2]
        CreateRemoteQuESTEnv[___] := invalidArgError[CreateRemoteQuESTEnv]
                    
        CreateLocalQuESTEnv[arg_:"quest_link"] := With[
            {fn = arg <> If[$OperatingSystem === "Windows", ".exe", ""]},
            If[
                FileExistsQ[fn], 
                Install[fn],  
                Message[CreateLocalQuESTEnv::error, "Local quest_link executable not found!"]; $Failed]
            ]
        CreateLocalQuESTEnv[__] := invalidArgError[CreateLocalQuESTEnv] (* no args is valid *)
            
        getExecFn["MacOS"|"MacOSX"] = "macos_x86_quest_link";
        getExecFn["MacOS M1"|"MacOSX M1"] = "macos_arm_quest_link";
        getExecFn["Windows"] = "windows_quest_link.exe";
        getExecFn["Linux"|"Unix"] = "linux_quest_link";
        CreateDownloadedQuESTEnv[os:("MacOS"|"MacOSX"|"MacOS M1"|"MacOSX M1"|"Windows"|"Linux"|"Unix")] := 
            Module[{url,resp,log,fn,exec},
                (* attempt download *)
                log = PrintTemporary["Downloading..."];
                url = "https://github.com/QTechTheory/QuESTlink/raw/main/Binaries/" <> getExecFn[os];
                fn = FileNameJoin[{Directory[], "quest_link"}];
                resp = Check[URLDownload[url, fn,  {"File", "StatusCode"}, TimeConstraint->20], $Failed];
                NotebookDelete[log];
                (* check response *)
                If[
                    resp === $Failed,
                    Message[CreateDownloadedQuESTEnv::error, "Download failed due to the above error."];
                    Return[$Failed, Module]
                ];
                If[resp["StatusCode"] >= 400,
                    Message[CreateDownloadedQuESTEnv::error, "Download failed; returned status code " <> ToString @ resp["StatusCode"]];
                    Return[$Failed, Module]
                ];
                (* install *)
                log = PrintTemporary["Installing..."];
                If[os =!= "Windows", 
                    Run["chmod +x " <> fn];
                    (* esoteric permissions problem. Machine gun hot fix, pow pow *)
                    Run["chmod +x " <> (ToString @@ resp["File"])];
                    Run["chmod +x " <> FileNameTake[fn]];
                ];
                exec = Install @ resp["File"];
                NotebookDelete[log];
                exec
            ]
        CreateDownloadedQuESTEnv[] := Module[
            {os = $OperatingSystem},
            If[ (os === "MacOS" || os === "MacOSX") && Not @ StringContainsQ[$System, "x86"],
                os = "MacOS M1"
            ];
            CreateDownloadedQuESTEnv[os]
        ]
        CreateDownloadedQuESTEnv[__] := (
            Message[CreateDownloadedQuESTEnv::error, "Supported operating systems are Windows, Linux, Unix, MacOS, MacOSX, MacOS M1, MacOSX M1"]; 
            $Failed)
                    
        DestroyQuESTEnv[link_] := Uninstall @ link
        DestroyQuESTEnv[___] := invalidArgError[DestroyQuESTEnv]
        
        
        
        (*
         * state getters and setters 
         *)
         
        (* Im[0.] = 0, how annoying *)
        SetWeightedQureg[fac1_?NumericQ, q1_Integer, fac2_?NumericQ, q2_Integer, facOut_?NumericQ, qOut_Integer] :=
            SetWeightedQuregInternal[
                q1, q2, qOut,
                Re @ N @ fac1, N @ Im @ N @ fac1,
                Re @ N @ fac2, N @ Im @ N @ fac2,
                Re @ N @ facOut, N @ Im @ N @ facOut
            ]
        SetWeightedQureg[fac1_?NumericQ, q1_Integer, fac2_?NumericQ, q2_Integer, qOut_Integer] :=
            SetWeightedQuregInternal[
                q1, q2, qOut,
                Re @ N @ fac1, N @ Im @ N @ fac1,
                Re @ N @ fac2, N @ Im @ N @ fac2,
                0., 0.
            ]
        SetWeightedQureg[fac1_?NumericQ, q1_Integer, qOut_Integer] :=
            SetWeightedQuregInternal[
                q1, q1, qOut,
                Re @ N @ fac1, N @ Im @ N @ fac1,
                0., 0.,
                0., 0.
            ]
        SetWeightedQureg[fac_?NumericQ, qOut_Integer] :=
            SetWeightedQuregInternal[
                qOut, qOut, qOut,
                0., 0., 
                0., 0.,
                Re @ N @ fac, N @ Im @ N @ fac
            ]
        SetWeightedQureg[___] := invalidArgError[SetWeightedQureg]
        
        GetAmp[qureg_Integer, index_Integer] := GetAmpInternal[qureg, index, -1]
        GetAmp[qureg_Integer, row_Integer, col_Integer] := GetAmpInternal[qureg, row, col]
        GetAmp[___] := invalidArgError[GetAmp]
        
        SetAmp[qureg_Integer, index_Integer, amp_?NumericQ] := SetAmpInternal[qureg, N@Re@N@amp, N@Im@N@amp, index, -1]
        SetAmp[qureg_Integer, row_Integer, col_Integer, amp_?NumericQ] := SetAmpInternal[qureg, N@Re@N@amp, N@Im@N@amp, row, col]
        SetAmp[___] := invalidArgError[SetAmp]
        
        
        
        (*
         * phase functions
         *)
        
        (* for extracting {coeffs}, {exponents} from a 1D exponential-polynomial *)
        extractCoeffExpo[s_Symbol][c_?NumericQ] := {c,0}
        extractCoeffExpo[s_Symbol][s_Symbol] := {1,1}
        extractCoeffExpo[s_Symbol][Verbatim[Times][c_?NumericQ, s_Symbol]] := {c,1}
        extractCoeffExpo[s_Symbol][Verbatim[Power][s_Symbol,e_?NumericQ]] := {1,e}
        extractCoeffExpo[s_Symbol][Verbatim[Times][c_?NumericQ, Verbatim[Power][s_Symbol,e_?NumericQ]]] := {c,e}
        extractCoeffExpo[s_Symbol][badTerm_] := {$Failed, badTerm}
        extractExpPolyTerms[poly_Plus, s_Symbol] :=
            extractCoeffExpo[s] /@ List @@ poly
        extractExpPolyTerms[term_, s_Symbol] :=
            {extractCoeffExpo[s] @ term}
            
        (* for extracting {coeffs}, {exponents} from an n-D exponential-polynomial *)
        extractMultiExpPolyTerms[terms_List, symbs:{__Symbol}] := 
            Module[{coeffs,powers, cp, badterms},
                coeffs = Association @@ Table[s->{},{s,symbs}];
                powers = Association @@ Table[s->{},{s,symbs}];
                badterms = {};
                (* for each term... *)
                Do[
                    (* attempting extraction of term via each symbol *)
                    Do[
                        cp = extractCoeffExpo[s][term];
                        If[ First[cp] =!= $Failed,
                            AppendTo[coeffs[s], cp[[1]]];
                            AppendTo[powers[s], cp[[2]]];
                            Break[]],
                        {s, symbs}];
                    (* if no symbol choice admitted a recognised term, record term *)
                    If[ First[cp] === $Failed,
                        AppendTo[badterms, cp]];
                    (* otherwise, proceed through all terms *)
                    , {term, terms}];
                (* return bad terms if encountered, else term info *)
                If[badterms === {}, 
                    {Values @ coeffs, Values @ powers},
                    badterms]]
        extractMultiExpPolyTerms[poly_Plus, symbs:{__Symbol}] := 
            extractMultiExpPolyTerms[List @@ poly, symbs]
        extractMultiExpPolyTerms[term_, symbs:{__Symbol}] := 
            extractMultiExpPolyTerms[{term}, symbs]
            
        bitEncodingFlags = {  (* these must match the values of the enum bitEncoding in QuEST.h *)
            "Unsigned" -> 0,
            "TwosComplement" -> 1
        };
        phaseFuncFlags = {    (* these must match the values of the enum phaseFunc in QuEST.h *)
            "Norm" -> 0,
            "ScaledNorm" -> 1,
            "InverseNorm" -> 2,
            "ScaledInverseNorm" -> 3,
            "ScaledInverseShiftedNorm" -> 4,
            
            "Product" -> 5,
            "ScaledProduct" -> 6,
            "InverseProduct" -> 7,
            "ScaledInverseProduct" -> 8,
            
            "Distance" -> 9,
            "ScaledDistance" -> 10,
            "InverseDistance" -> 11,
            "ScaledInverseDistance" -> 12,
            "ScaledInverseShiftedDistance" -> 13,
            "ScaledInverseShiftedWeightedDistance" -> 14
        };
        Options[ApplyPhaseFunc] = {
            BitEncoding -> "Unsigned",
            PhaseOverrides -> {}
        };
        
        (* single-variable exponential polynomial func *)
        ApplyPhaseFunc[qureg_Integer, reg:{__Integer}, func_, symb_Symbol, OptionsPattern[]] := With[
            {terms = extractExpPolyTerms[N @ func, symb]},
            {badterms = Cases[terms, {$Failed, bad_} :> bad]},
            {overs = OptionValue[PhaseOverrides]},
            Which[
                Length[badterms] > 0,
                    (Message[ApplyPhaseFunc::error, "The phase function, which must be an exponential-polynomial, contained an unrecognised term of the form " <> ToString@StandardForm@First@badterms <> "."]; 
                    $Failed),
                Not @ MemberQ[bitEncodingFlags[[All,1]], OptionValue[BitEncoding]],
                    (Message[ApplyPhaseFunc::error, "Invalid option for BitEncoding. Must be one of " <> ToString@bitEncodingFlags[[All, 1]] <> "."]; 
                    $Failed),
                Not @ MatchQ[overs, {(_Integer -> _?Internal`RealValuedNumericQ) ...}],
                    (Message[ApplyPhaseFunc::error, "Invalid one-dimensional PhaseOverrides, which must be of the form {integer -> real, ...}"]; 
                    $Failed),
                True,
                    ApplyPhaseFuncInternal[qureg, reg, OptionValue[BitEncoding] /. bitEncodingFlags, terms[[All,1]], terms[[All,2]], overs[[All,1]], N @ overs[[All,2]]]]]
            
        (* multi-variable exponential polynomial func *)
        ApplyPhaseFunc[qureg_Integer, regs:{{__Integer}..}, func_, symbs:{__Symbol}, OptionsPattern[]] := With[
            {terms = extractMultiExpPolyTerms[N @ func, symbs]},
            {badterms = Cases[terms, {$Failed, bad_} :> bad]},
            {coeffs = First[terms], exponents=Last[terms]},
            {overs = OptionValue[PhaseOverrides]},
            Which[
                Not @ DuplicateFreeQ @ symbs,
                    (Message[ApplyPhaseFunc::error, "The list of phase function symbols must be unique."];
                    $Failed),
                Length[regs] =!= Length[symbs],
                    (Message[ApplyPhaseFunc::error, "Each delimited sub-register of qubits must correspond to a unique symbol in the phase function."];
                    $Failed),
                Length[badterms] > 0,
                    (Message[ApplyPhaseFunc::error, "The phase function, which must be an exponential-polynomial, contained an unrecognised term of the form " <> ToString@StandardForm@First@badterms <> "."]; 
                     $Failed),
                Not @ MemberQ[bitEncodingFlags[[All,1]], OptionValue[BitEncoding]],
                    (Message[ApplyPhaseFunc::error, "Invalid option for BitEncoding. Must be one of " <> ToString@bitEncodingFlags[[All, 1]] <> "."]; 
                    $Failed),
                Not[ (overs === {}) || And[
                        MatchQ[overs, {({__Integer} -> _?Internal`RealValuedNumericQ) ..}],
                        Equal @@ Length /@ overs[[All,1]], 
                        Length[regs] === Length@overs[[1,1]] ] ],
                    (Message[ApplyPhaseFunc::error, "Invalid PhaseOverrides. Each overriden phase index must be specified as an n-tuple, where n is the number of sub-registers and symbols, pointing to a real number. For example, ApplyPhaseFunc[..., {x,y}, PhaseOverrides -> { {0,0} -> PI, ... }]."];
                     $Failed),
                True,
                    ApplyMultiVarPhaseFuncInternal[qureg, Flatten[regs], Length/@regs, OptionValue[BitEncoding] /. bitEncodingFlags, Flatten[coeffs], Flatten[exponents], Length/@coeffs, Flatten[overs[[All,1]]], N @ overs[[All,2]]]]]

        (* parameterised named func (multi-variable) *)
        ApplyPhaseFunc[qureg_Integer, regs:{{__Integer}..}, {func_String, params___?Internal`RealValuedNumericQ}, OptionsPattern[]] := With[
            {overs = OptionValue[PhaseOverrides]},
            Which[
                Not @ MemberQ[phaseFuncFlags[[All,1]], func],
                    (Message[ApplyPhaseFunc::error, "The named phase function must be one of " <> ToString[phaseFuncFlags[[All,1]]]]; 
                     $Failed),
                Not @ MemberQ[bitEncodingFlags[[All,1]], OptionValue[BitEncoding]],
                    (Message[ApplyPhaseFunc::error, "Invalid option for BitEncoding. Must be one of " <> ToString@bitEncodingFlags[[All, 1]] <> "."]; 
                    $Failed),
                Not[ (overs === {}) || And[
                        MatchQ[overs, {({__Integer} -> _?Internal`RealValuedNumericQ) ..}],
                        Equal @@ Length /@ overs[[All,1]], 
                        Length[regs] === Length@overs[[1,1]] ] ],
                    (Message[ApplyPhaseFunc::error, "Invalid PhaseOverrides. Each overriden phase index must be specified as an n-tuple, where n is the number of sub-registers, pointing to a real number. For example, ApplyPhaseFunc[..., {{1},{2}}, ..., PhaseOverrides -> { {0,0} -> PI, ... }]."];
                     $Failed),
                StringEndsQ[func, "Distance"] && OddQ @ Length @ regs,
                    (Message[ApplyPhaseFunc::error, "'Distance' based phase functions require a strictly even number of subregisters, since every pair is assumed to represent the same coordinate."]; 
                    $Failed),
                Length[{params}] === 0,
                    ApplyNamedPhaseFuncInternal[qureg, Flatten[regs], Length/@regs, OptionValue[BitEncoding] /. bitEncodingFlags, func /. phaseFuncFlags, Flatten[overs[[All,1]]], N @ overs[[All,2]]],
                Length[{params}] > 0,
                    ApplyParamNamedPhaseFuncInternal[qureg, Flatten[regs], Length/@regs, OptionValue[BitEncoding] /. bitEncodingFlags, func /. phaseFuncFlags, N @ {params}, Flatten[overs[[All,1]]], N @ overs[[All,2]]]]]
        
        (* non-parameterised named func (multi-variable) *)
        ApplyPhaseFunc[qureg_Integer, regs:{{__Integer}..}, func_String, opts:OptionsPattern[]] := 
            ApplyPhaseFunc[qureg, regs, {func}, opts]
        
        (* invalid args and symbol syntax highlighting *)
        ApplyPhaseFunc[___] := invalidArgError[ApplyPhaseFunc]
        SyntaxInformation[ApplyPhaseFunc] = {"LocalVariables" -> {"Solve", {4, 4}}};
        
        
        
        (* 
         * Below is only front-end code for analytically simplifying expressions 
         * of Pauli tensors
         *)
         
         (* post-processing step to combine Pauli products that have identical symbols and indices... *)
        getPauliSig[ a: pauliOpPatt ] := {a}
        getPauliSig[ Verbatim[Times][t__] ] := Cases[{t}, pauliOpPatt]
        getPauliSig[ _ ] := {}
        (* which works by splitting a sum into groups containing the same Pauli tensor, and simplifying each *)
        factorPaulis[s_Plus] := Total[Simplify /@ Plus @@@ GatherBy[List @@ s, getPauliSig]] /. Complex[0.`, 0.`] -> 0
        factorPaulis[e_] := e
        
        (* SimplifyPaulis prevents Mathemtica commutation (and inadvertently, variable substitution)
         * in order to perform all operator simplification correctly. It accepts expressions containing 
         * sums, products, powers and non-commuting multiples of Pauli operators (literals, and in variables), 
         * and the structures of remaining patterns/symbols/expressions can be anything at all.
         *)
        SetAttributes[SimplifyPaulis, HoldAll]
        SetAttributes[innerSimplifyPaulis, HoldAll]
        
        (* below, we deliberately do not constrain indices to be _Integer (ergo avoid pauliOpPatt), to permit symbols *)

        innerSimplifyPaulis[ a:Subscript[pauliCodePatt, _] ] :=  
            a

        innerSimplifyPaulis[ (a:Subscript[pauliCodePatt, q_])^n_Integer?NonNegative ] :=
            If[EvenQ[n], Subscript[Id,q], a]
            
        innerSimplifyPaulis[ Verbatim[Times][t__] ] := With[
            (* hold each t (no substitutions), simplify each, release hold, simplify each (with subs) *)
            {nc = innerSimplifyPaulis /@ (NonCommutativeMultiply @@ (innerSimplifyPaulis /@ Hold[t]))},
            (* pass product (which now contains no powers of pauli expressions) to simplify *)
            innerSimplifyPaulis[nc]]

        innerSimplifyPaulis[ Power[b_, n_Integer?NonNegative] ] /; Not @ FreeQ[b,Subscript[pauliCodePatt, _]] :=
            (* simplify the base, then pass a (non-expanded) product to simplify (to trigger above def) *)
            With[{s=ConstantArray[innerSimplifyPaulis[b], n]}, 
                innerSimplifyPaulis @@ (Times @@@ Hold[s])]
                
        innerSimplifyPaulis[ Plus[t__] ] := With[
            (* hold each t (no substitutions), simplify each, release hold, simplify each (with subs) *)
            {s = Plus @@ (innerSimplifyPaulis /@ (List @@ (innerSimplifyPaulis /@ Hold[t])))},
            (* combine identical Pauli tensors in the resulting sum *)
            factorPaulis[s]
        ]

        innerSimplifyPaulis[ NonCommutativeMultiply[t__] ] := With[
            (* hold each t (no substitutions), simplify each, release hold, simplify each (with subs) *)
            {s = innerSimplifyPaulis /@ (NonCommutativeMultiply @@ (innerSimplifyPaulis /@ Hold[t]))},
            (* expand all multiplication into non-commuting; this means ex can be a sum now *)
            {ex = Distribute[s /. Times -> NonCommutativeMultiply]},
            (* notation shortcuts *)
            {xyz = X|Y|Z, xyzi = pauliCodePatt, ncm = NonCommutativeMultiply}, 
            (* since ex can now be a sum, after below transformation, factorise *)
            factorPaulis[
                ex //. {
                (* destroy exponents of single terms *)
                (a:Subscript[xyzi, q_])^n_Integer  /; (n >= 0) :> If[EvenQ[n], Subscript[Id,q], a], 
                (a:Subscript[Id, _])^n_Integer :> a,
                (* move scalars to their own element (to clean pauli pattern) *)
                ncm[r1___, (f:Except[Subscript[xyzi, _]]) (a:Subscript[xyzi, _]) , r2___] :> ncm[f,r1,a,r2],
                (* map same-qubit adjacent (closest) pauli matrices to their product *)
                ncm[r1___, Subscript[(a:xyz), q_], r2:Shortest[___],Subscript[(b:xyz), q_], r3___] :>
                    If[a === b, 
                        (* XX = YY = ZZ = Id *)
                        ncm[r1,r2,r3,Subscript[Id,q]],
                        (* AB = (+-) i C *)
                        With[{c = First @ Complement[List@@xyz, {a,b}]},
                            ncm[r1, I Signature@{a,b,c} Subscript[c, q], r2, r3]]],
                (* remove superfluous Id's when multiplying onto other paulis on any qubits *)
                ncm[r1___, Subscript[Id, _], r2___, b:Subscript[xyzi, _], r3___] :>
                    ncm[r1, r2, b, r3],
                ncm[r1___, a:Subscript[xyzi, _], r2___, Subscript[Id, _], r3___] :>
                    ncm[r1, a, r2, r3]
            (* finally, restore products (overwriting user non-comms) and simplify scalars *)
            } /. NonCommutativeMultiply -> Times]]
            
        innerSimplifyPaulis[uneval_] := With[
            (* let everything else evaluate (to admit scalars, or let variables be substituted *)
            {eval=uneval},
            Which[
                (* if evaluation changed expression, attempt to simplify the new form *)
                Unevaluated[uneval] =!= eval,  (* =!= is smart enough to ignore Unevaluated[], wow! *)
                    innerSimplifyPaulis[eval],
                (* if expression is unchanged and contains no paulis, leave it as is *)
                FreeQ[uneval, Subscript[pauliCodePatt, _]],
                    uneval,
                (* if expression is a single (and ergo unchanging) Pauli, permit it *)
                MatchQ[uneval, Subscript[pauliCodePatt, _]],
                    uneval,
                (* otherwise this is an unrecognised Pauli sub-expression *)
                True,
                    (* raise Message (without $Failed because Message causes immediate abort) *)
                    Message[SimplifyPaulis::error, 
                        "Input contained the following sub-expression of Pauli operators which could not be simplified: " <> 
                        ToString @ StandardForm @ uneval]]]

        SimplifyPaulis[expr_] :=
            Enclose[
                (* immediately abort upon unrecognised sub-expression *)
                ConfirmQuiet @ innerSimplifyPaulis @ expr,
                (ReleaseHold @ # @ "HeldMessageCall"; $Failed) & ]

        SimplifyPaulis[__] := invalidArgError[SimplifyPaulis]
        
        
        
        (*
         * Below is only front-end code for generating 3D plots of density matrices
         *)
         
        Options[PlotDensityMatrix] = {
            BarSpacing -> .5,
            PlotComponent -> "Magnitude",
            ChartElementFunction -> "ProfileCube"
        };
        
        isNumericSquareMatrix[matrix_?MatrixQ] :=
            And[SquareMatrixQ @ matrix, AllTrue[Flatten @ matrix, NumericQ]]
        isNumericSquareMatrix[_] :=
            False
        isNumericVector[vector_?VectorQ] :=
            AllTrue[Flatten @ vector, NumericQ]
        isNumericVector[_] :=
            False
            
        extractMatrixData[comp_, matrix_] := With[
            {data = Switch[comp,
                "Real", Re @ matrix,
                "Imaginary", Im @ matrix,
                "Magnitude", Abs @ matrix,
                _, $Failed]},
            If[data === $Failed, Message[PlotDensityMatrix::error, "PlotComponent must be \"Real\", \"Imaginary\" or \"Magnitude\"."]];
            data]
        extractWeightedData[data_] :=
            WeightedData[Join @@ Array[List, Dimensions@#], Join @@ #]& @ Abs @ data (* forced positive *)
        extractChartElemFunc[func_] := With[
            {elem=(func /. Automatic -> 
                OptionValue[Options[PlotDensityMatrix], ChartElementFunction])},
            If[Not @ StringQ @ elem, 
                Message[PlotDensityMatrix::error, "ChartElementFunction must be a string, or Automatic. See available options with ChartElementData[Histogram3D]."]; 
                $Failed,
                elem]]
        extractBarSpacing[val_] := With[
            {space = (val /. Automatic -> OptionValue[Options[PlotDensityMatrix], BarSpacing])},
            If[Not[NumericQ@space] || Not[0 <= space < 1],
                Message[PlotDensityMatrix::error, "BarSpacing (Automatic is .5) must be a number between 0 (inclusive) and 1 (exclusive)."];
                $Failed,
                space]]
            
        plotDensOptsPatt = OptionsPattern[{PlotDensityMatrix,Histogram3D}];
         
        (* single matrix plot *)
        PlotDensityMatrix[id_Integer, opts:plotDensOptsPatt] :=
            PlotDensityMatrix[GetQuregState[id], opts]
        PlotDensityMatrix[matrix_?isNumericSquareMatrix, opts:plotDensOptsPatt] :=
            Block[{data, chartelem, space, offset},
                (* unpack data and args (may throw Message) *)
                data = extractMatrixData[OptionValue[PlotComponent], matrix];
                chartelem = extractChartElemFunc[OptionValue[ChartElementFunction]];
                space = extractBarSpacing[OptionValue[BarSpacing]];
                offset = space {1,-1}/2;
                (* return early if error *)
                If[MemberQ[{data,chartelem,space}, $Failed], Return[$Failed]];
                (* plot *)
                Histogram3D[
                    extractWeightedData[data], 
                    Times @@ Dimensions @ data,
                    (* offset and possibly under-axis (negative values) bar graphics *)
                    ChartElementFunction->
                        Function[{region, inds, meta}, ChartElementData[chartelem][
                            (* we subtract "twice" negative values, to point e.g. cones downard *)
                            region + {offset, offset, {0, 2 Min[0, Extract[data, First@inds]]}}, inds, meta]],
                    (* with user Histogram3D options *)
                    FilterRules[{opts}, Options[Histogram3D]],
                    (* and our overridable defaults *)
                    ColorFunction -> (ColorData["DeepSeaColors"][1 - #] &),
                    PlotRange -> {
                        .5 + {0, First @ Dimensions @ data},
                        .5 + {0, Last @ Dimensions @ data},
                        Automatic}
                ]
            ]
        (* two matrix plot *)
        PlotDensityMatrix[id1_Integer, id2_Integer, opts:plotDensOptsPatt] :=
            PlotDensityMatrix[GetQuregState[id1], GetQuregState[id2], opts]
        PlotDensityMatrix[id1_Integer, matr2_?isNumericSquareMatrix, opts:plotDensOptsPatt] :=
            PlotDensityMatrix[GetQuregState[id1], matr2, opts]
        PlotDensityMatrix[matr1_?isNumericSquareMatrix, id2_Integer, opts:plotDensOptsPatt] :=
            PlotDensityMatrix[matr1, GetQuregState[id2], opts]
        PlotDensityMatrix[matr1_?isNumericSquareMatrix, vec2_?isNumericVector, opts:plotDensOptsPatt] :=
            With[{matr2 = KroneckerProduct[ConjugateTranspose@{vec2}, vec2]},
                PlotDensityMatrix[matr1, matr2, opts]]
        PlotDensityMatrix[matr1_?isNumericSquareMatrix, matr2_?isNumericSquareMatrix, opts:plotDensOptsPatt] :=
            Block[{data1, data2, chartelem, space, offset},
                (* unpack data and args (may throw Message) *)
                data1 = extractMatrixData[OptionValue[PlotComponent], matr1];
                data2 = extractMatrixData[OptionValue[PlotComponent], matr2];
                chartelem = extractChartElemFunc[OptionValue[ChartElementFunction]];
                space = extractBarSpacing[OptionValue[BarSpacing]];
                offset = space {1,-1}/2;
                (* return early if error *)
                If[MemberQ[{data1,data2,chartelem,space}, $Failed], Return[$Failed]];
                (* plot *)
                Histogram3D[
                    {extractWeightedData[data1], extractWeightedData[data2]}, 
                    Max[Times @@ Dimensions @ data1, Times @@ Dimensions @ data2],
                    (* offset and possibly under-axis (negative values) bar graphics *)
                    ChartElementFunction -> {
                        Function[{region, inds, meta}, ChartElementData[chartelem][
                            (* we subtract "twice" negative values, to point e.g. cones downard *)
                            region + {offset, offset, {0, 2 Min[0, Extract[data1, First@inds]]}}, inds, meta]],
                        Function[{region, inds, meta}, ChartElementData[chartelem][
                            (* we make the second matrix bars slightly inside the first's *)
                            region + {1.001 offset, 1.001 offset, {0, 2 Min[0, Extract[data2, First@inds]]}}, inds, meta]]
                        },
                    (* with user Histogram3D options *)
                    FilterRules[{opts}, Options[Histogram3D]],
                    (* and our overridable defaults *)
                    ChartStyle -> {Opacity[1], Opacity[.3]},
                    ColorFunction -> (ColorData["DeepSeaColors"][1 - #] &),
                    PlotRange -> {
                        .5 + {0, Max[First @ Dimensions @ data1, First @ Dimensions @ data2]},
                        .5 + {0, Max[Last @ Dimensions @ data1, Last @ Dimensions @ data2]},
                        Automatic},
                    (* useless placebo *)
                    Method -> {"RelieveDPZFighting" -> True}
                ]
            ]
        PlotDensityMatrix[___] := (
            Message[PlotDensityMatrix::error, "Invalid arguments. See ?PlotDensityMatrix. Note the first argument must be a numeric square matrix."]; 
            $Failed)
        
        
        
        (*
         * Below is only front-end code for generating circuit diagrams from
         * from circuit the same format circuit specification
         *)
         
        (* convert symbolic gate form to {symbol, ctrls, targets} *)
        getSymbCtrlsTargs[Subscript[C, (ctrls:__Integer)|{ctrls:__Integer}][ R[arg_, Verbatim[Times][paulis:pauliOpPatt..]] ]] := {Join[{R}, {paulis}[[All,1]]], {ctrls}, {paulis}[[All,2]]}
        getSymbCtrlsTargs[Subscript[C, (ctrls:__Integer)|{ctrls:__Integer}][ R[arg_, Subscript[pauli:pauliCodePatt, targ_Integer]] ]] := {{R,pauli}, {ctrls}, {targ}}
        getSymbCtrlsTargs[Subscript[C, (ctrls:__Integer)|{ctrls:__Integer}][Subscript[gate_Symbol, (targs:__Integer)|{targs:__Integer}][args__]]] := {gate, {ctrls}, {targs}}
        getSymbCtrlsTargs[Subscript[C, (ctrls:__Integer)|{ctrls:__Integer}][Subscript[gate_Symbol, (targs:__Integer)|{targs:__Integer}]]] := {gate, {ctrls}, {targs}}
        getSymbCtrlsTargs[Subscript[gate_Symbol, (targs:__Integer)|{targs:__Integer}][args__]] := {gate, {},{targs}}
        getSymbCtrlsTargs[Subscript[gate_Symbol, (targs:__Integer)|{targs:__Integer}]] := {gate, {}, {targs}}
        getSymbCtrlsTargs[R[arg_, Verbatim[Times][paulis:pauliOpPatt..]]] := {Join[{R}, {paulis}[[All,1]]], {}, {paulis}[[All,2]]}
        getSymbCtrlsTargs[R[arg_, Subscript[pauli:(X|Y|Z), targ_Integer]]] := {{R,pauli}, {}, {targ}}
            (* little hack to enable G[x] and Fac[y] in GetCircuitColumns *)
            getSymbCtrlsTargs[G[x_]] := {G, {}, {}}
            getSymbCtrlsTargs[Fac[x_]] := {Fac, {}, {}}

        (* deciding how to handle gate placement *)
        getQubitInterval[{ctrls___}, {targs___}] :=
            Interval @ {Min[ctrls,targs],Max[ctrls,targs]}
        getNumQubitsInCircuit[circ_List] :=
            Max[1 + Cases[{circ}, Subscript[gate_, inds__]-> Max[inds], Infinity],    
                1 + Cases[{circ}, Subscript[gate_, inds__][___] -> Max[inds], Infinity]] /. -Infinity -> 1  (* assume G and Fac circuits are 1 qubit *)
        isContiguousBlockGate[(SWAP|M|Rz|Ph|X|R|{R, pauliCodePatt..})] := False
        isContiguousBlockGate[_] := True
        needsSpecialSwap[label_, _List] /; Not[isContiguousBlockGate[label]] := False
        needsSpecialSwap[label_Symbol, targs_List] :=
            And[Length[targs] === 2, Abs[targs[[1]] - targs[[2]]] > 1]
        getFixedThenBotTopSwappedQubits[{targ1_,targ2_}] :=
            {Min[targ1,targ2],Min[targ1,targ2]+1,Max[targ1,targ2]}
            
        (* gate and qubit graphics primitives *)
        drawCross[targ_, col_] := {
            Line[{{col+.5,targ+.5}-{.1,.1},{col+.5,targ+.5}+{.1,.1}}],
            Line[{{col+.5,targ+.5}-{-.1,.1},{col+.5,targ+.5}+{-.1,.1}}]}
        drawControls[{ctrls__}, {targs___}, col_] := {
            FaceForm[Black],
            Table[Disk[{col+.5,ctrl+.5},.1],{ctrl,{ctrls}}],
            With[{top=Max@{ctrls,targs},bot=Min@{ctrls,targs}},
                Line[{{col+.5,bot+.5},{col+.5,top+.5}}]]}
        drawSingleBox[targ_, col_] :=
            Rectangle[{col+.1,targ+.1}, {col+1-.1,targ+1-.1}]
        drawDoubleBox[targ_, col_] :=
            Rectangle[{col+.1,targ+.1}, {col+1-.1,targ+2-.1}]
        drawMultiBox[minTarg_, numTargs_, col_] :=
            Rectangle[{col+.1,minTarg+.1}, {col+1-.1,minTarg+numTargs-.1}]
        drawQubitLines[qubits_List, col_, width_:1] :=
            Table[Line[{{col,qb+.5},{col+width,qb+.5}}], {qb,qubits}]
        drawSpecialSwapLine[targ1_, targ2_, col_] := {
            Line[{{col,targ1+.5},{col+.1,targ1+.5}}],
            Line[{{col+.1,targ1+.5},{col+.5-.1,targ2+.5}}],
            Line[{{col+.5-.1,targ2+.5},{col+.5,targ2+.5}}]}
        drawSpecialSwap[targ1_,targ2_,col_] := {
            drawSpecialSwapLine[targ1,targ2,col],
            drawSpecialSwapLine[targ2,targ1,col]}
            
        (* special gate graphics *)
        drawGate[SWAP, {}, {targs___}, col_] := {
            (drawCross[#,col]&) /@ {targs},
            Line[{{col+.5,.5+Min@targs},{col+.5,.5+Max@targs}}]}
        drawGate[Z, {ctrls__}, {targ_}, col_] := {
            drawControls[{ctrls,targ},{targ},col],
            Line[{{col+.5,.5+Min@ctrls},{col+.5,.5+Max@ctrls}}]}
        drawGate[Ph, {ctrls___}, {targs__}, col_] := {
            drawControls[{ctrls,targs},{},col],
            Text["\[Theta]", {col+.75,Min[{ctrls,targs}]+.75}]}
        drawGate[label:(Kraus|KrausNonTP|Damp|Deph|Depol), {}, targs_List, col_] := {
            EdgeForm[Dashed],
            drawGate[label /. {
                    Kraus -> \[Kappa], KrausNonTP -> \[Kappa]NTP, Damp -> \[Gamma], 
                    Deph -> \[Phi], Depol -> \[CapitalDelta]},
                {}, targs, col]}

        (* single qubit gate graphics *)
        drawGate[Id, {}, {targs___}, col_] :=
            {}
        drawGate[visibleId, {}, {targ_}, col_] := {
            drawSingleBox[targ, col],
            Text["\[DoubleStruckOne]", {col+.5,targ+.5}]
        }
        drawGate[visibleId, {}, {targs___}, col_] :=
            drawGate[visibleId, {}, #, col]& /@ {targs}
        drawGate[M, {}, {targs___}, col_] :=
            Table[{
                drawSingleBox[targ,col],
                Circle[{col+.5,targ+.5-.4}, .4, {.7,\[Pi]-.7}],
                Line[{{col+.5,targ+.5-.25}, {col+.5+.2,targ+.5+.3}}]
                }, {targ, {targs}}]

        drawGate[Depol, {}, {targ_}, col_] := {
            EdgeForm[Dashed], drawGate[\[CapitalDelta], {}, {targ}, col]}
        drawGate[X, {}, {targ_}, col_] := {
            Circle[{col+.5,targ+.5},.25],
            Line[{{col+.5,targ+.5-.25},{col+.5,targ+.5+.25}}]}
        drawGate[label_Symbol, {}, {targ_}, col_] := {
            drawSingleBox[targ, col],
            Text[SymbolName@label, {col+.5,targ+.5}]}
            
        (* multi-qubit gate graphics *)
        drawGate[Rz, {}, targs_List, col_] := {
            Line[{{col+.5,Min[targs]+.5},{col+.5,Max[targs]+.5}}],
            Sequence @@ (drawGate[Rz, {}, {#1}, col]& /@ targs)}
        drawGate[{R, rots:pauliCodePatt..}, {}, targs_List, col_] := {
            Line[{{col+.5,Min[targs]+.5},{col+.5,Max[targs]+.5}}],
            Sequence @@ MapThread[drawGate[#1/.{X->Rx,Y->Ry,Z->Rz,Id->visibleId}, {}, {#2}, col]&, {{rots}, targs}]}
        drawGate[G, {}, targs_List, col_] /; (isContiguousBlockGate[label] && Union@Differences@Sort@targs=={1}) := {
            drawMultiBox[Min[targs], Length[targs], col],
            Text["e"^"i\[Theta]", {col+.5,Mean[targs]+.5}]}
        drawGate[Fac, {}, targs_List, col_] /; (isContiguousBlockGate[label] && Union@Differences@Sort@targs=={1}) := {
            drawMultiBox[Min[targs], Length[targs], col],
            Text[Rotate["factor",Pi/2], {col+.5,Mean[targs]+.5}]}
        drawGate[label_Symbol, {}, targs_List, col_] /; (isContiguousBlockGate[label] && Union@Differences@Sort@targs=={1}) := {
            drawMultiBox[Min[targs], Length[targs], col],
            Text[SymbolName@label, {col+.5,Mean[targs]+.5}]}
        drawGate[label_Symbol, {}, targs_List, col_] := {
            Line[{{col+.5,Min[targs]+.5},{col+.5,Max[targs]+.5}}],
            Sequence @@ (drawGate[label, {}, {#1}, col]& /@ targs)}
                
        (* two-qubit gate graphics *)
        drawGate[X, {}, targs:{targ1_,targ2_}, col_] := {
            Line[{{col+.5,targ1+.5},{col+.5,targ2+.5}}],
            Sequence @@ (drawGate[X, {}, {#1}, col]& /@ targs)}
        drawGate[label_Symbol, {}, {targ1_,targ2_}/;Abs[targ2-targ1]===1, col_] := {
            drawDoubleBox[Min[targ1,targ2], col],
            Text[SymbolName@label, {col+.5,Min[targ1,targ2]+.5+.5}]}
        drawGate[label_Symbol, {}, {targ1_,targ2_}, col_] := 
            With[{qb = getFixedThenBotTopSwappedQubits[{targ1,targ2}]}, {
                drawSpecialSwap[qb[[3]], qb[[2]], col],
                drawGate[label, {}, {qb[[1]],qb[[2]]}, col+.5],
                drawSpecialSwap[qb[[3]],qb[[2]],col+.5+1]}]
                
        (* controlled gate graphics *)
        drawGate[SWAP, {ctrls__}, {targs__}, col_] := {
            drawControls[{ctrls},{targs},col],
            drawGate[SWAP, {}, {targs}, col]}
        drawGate[ops:{R, (X|Y|Z)..}, {ctrls__}, {targs__}, col_] := {
            drawControls[{ctrls},{targs},col],
            drawGate[ops, {}, {targs}, col]}
        drawGate[label_Symbol, {ctrls__}, {targ_}, col_] := {
            drawControls[{ctrls},{targ},col],
            drawGate[label, {}, {targ}, col]}
        drawGate[label_Symbol, {ctrls__}, targs_List, col_] := {
            If[needsSpecialSwap[label,targs],
                With[{qb = getFixedThenBotTopSwappedQubits[targs]},
                    drawControls[{ctrls} /. qb[[2]]->qb[[3]], DeleteCases[targs,qb[[3]]], col+.5]],
                drawControls[{ctrls},targs, col]],
            drawGate[label, {}, targs, col]}
        
        (* generating background qubit lines in a whole circuit column *)
        drawQubitColumn[isSpecialSwapCol_, specialSwapQubits_, numQubits_, curCol_, width_:1] :=
            If[isSpecialSwapCol,
                (* for a special column, draw all middle lines then non-special left/right nubs *)
                With[{nonspecial=Complement[Range[0,numQubits-1], specialSwapQubits]}, {
                    drawQubitLines[Range[0,numQubits-1],curCol+.5,width],
                    drawQubitLines[nonspecial,curCol,width],
                    drawQubitLines[nonspecial,curCol+1,width]}],
                (* for a non special column, draw all qubit lines *)
                drawQubitLines[Range[0,numQubits-1],curCol,width]
            ]
            
        (* subcircuit seperator and scheduling label graphics *)
        drawSubcircSpacerLine[col_, numQubits_, style_] := 
            If[style === None, Nothing, {
                style,
                Line[{{col,0},{col,numQubits}}]}]
            
        (* labels below seperator *)
        defaultSubcircLabelDrawer[label_, col_] :=
            Rotate[Text[label, {col,-.5}], -15 Degree]
        defaultTimeLabelDrawer[time_, col_] := 
            defaultSubcircLabelDrawer[DisplayForm @ RowBox[{"t=",time}], col]
                
        (* optionally compactifies a circuit via GetColumnCircuits[] *)
        compactCirc[flag_][circ_] :=
            If[flag, Flatten @ GetCircuitColumns[circ], circ]
            
        (* creates a graphics description of the given list of subcircuits *)
        generateCircuitGraphics[subcircs_List, numQubits_Integer, opts___] := With[{
            
            (* unpack optional arguments *)
            subSpacing=OptionValue[{opts,Options[DrawCircuit]}, SubcircuitSpacing],
            dividerStyle=OptionValue[{opts,Options[DrawCircuit]}, DividerStyle],
            labelDrawFunc=OptionValue[{opts,Options[DrawCircuit]}, LabelDrawer],
            labels=OptionValue[{opts, Options[DrawCircuit]}, SubcircuitLabels],
            compactFlag=OptionValue[{opts,Options[DrawCircuit]}, Compactify]
            },
            
            (* prepare local variables *)
            Module[{
                qubitgraphics,gategraphics,
                curCol,curSymb,curCtrls,curTargs,curInterval,curIsSpecialSwap,
                prevIntervals,prevIsSpecialSwap,prevSpecialQubits,
                isFirstGate,subcircInd=0,subcircIndMax=Length[subcircs],
                gates,finalSubSpacing},

                (* outputs *)
                qubitgraphics = {};
                gategraphics = {};
                
                (* status of whether a gate can fit in the previous column *)
                curCol = 0;
                prevIntervals = {};
                prevIsSpecialSwap = False;
                prevSpecialQubits = {};
                
                (* draw divider left-of-circuit for the first label (else don't draw it) *)
                If[And[labelDrawFunc =!= None, labels =!= {}, First[labels] =!= None], 
                    AppendTo[gategraphics, drawSubcircSpacerLine[subSpacing/2, numQubits, dividerStyle]];
                    AppendTo[gategraphics, labelDrawFunc[First @ labels, subSpacing/2]];
                    AppendTo[qubitgraphics, drawQubitColumn[False, {} , numQubits, curCol + subSpacing/2, subSpacing/2]];
                    curCol = subSpacing;
                ];
                
                (* for each subcircuit... *)
                Table[
                    gates = compactCirc[compactFlag][subcirc /. {
                        (* hackily replace qubit-free gates full-state contiguous gate *)
                        G[_] -> Subscript[G, Range[0,numQubits-1] ], 
                        Fac[_] -> Subscript[Fac, Range[0,numQubits-1] ]}];
                    subcircInd++;
                    isFirstGate = True;
                
                    (* for each gate... *)
                    Table[
                    
                        (* extract data from gate *)
                        {curSymb,curCtrls,curTargs} = getSymbCtrlsTargs[gate];
                        curInterval = getQubitInterval[curCtrls,curTargs];
                        curIsSpecialSwap = needsSpecialSwap[curSymb,curTargs];
                        
                        (* decide whether gate will fit in previous column *)
                        If[Or[
                            And[curIsSpecialSwap, Not[prevIsSpecialSwap]],
                            AnyTrue[prevIntervals, (IntervalIntersection[curInterval,#] =!= Interval[]&)]],
                            (* will not fit: *)
                            (

                                (* draw qubit lines for the previous column (if it exists) *)
                                If[Not[isFirstGate],
                                    AppendTo[qubitgraphics,
                                        drawQubitColumn[prevIsSpecialSwap, prevSpecialQubits, numQubits, curCol]]];
                                
                                (* then make a new column *)
                                curCol = curCol + If[isFirstGate, 0, If[prevIsSpecialSwap,2,1]]; 
                                prevIntervals = {curInterval};
                                prevIsSpecialSwap = curIsSpecialSwap;
                                prevSpecialQubits = {};
                                    
                            ),
                            (* will fit *)
                            AppendTo[prevIntervals, curInterval]
                        ];
                        
                        (* record that this is no longer the first gate in the subcircuit *)
                        isFirstGate = False;
                        
                        (* record whether this gate requires special swaps *)
                        If[curIsSpecialSwap, 
                            With[{qbs=getFixedThenBotTopSwappedQubits[curTargs]},
                                AppendTo[prevSpecialQubits, qbs[[2]]];
                                AppendTo[prevSpecialQubits, qbs[[3]]]]];
                    
                        (* draw gate *)
                        AppendTo[gategraphics,
                            drawGate[
                                curSymb,curCtrls,curTargs,
                                curCol + If[prevIsSpecialSwap ~And~ Not[curIsSpecialSwap], .5, 0]]];        
                        ,
                        {gate,gates}
                    ];
                
                    (* perform the final round of qubit line drawing (for previous column),
                     * unless this is the final and empty subcircuit *) 
                    If[ subcircInd < subcircIndMax || Length@subcircs[[-1]] =!= 0,
                       AppendTo[qubitgraphics, 
                             drawQubitColumn[prevIsSpecialSwap, prevSpecialQubits, numQubits, curCol]]];
                        
                    (* make a new column (just accounting for previous subcircuit) *)
                    curCol = curCol + If[prevIsSpecialSwap,2,1]; 
                    prevIntervals = {};
                    prevIsSpecialSwap = False;
                    prevSpecialQubits = {};
                        
                    (* if this was not the final subcircuit... *)
                    If[subcircInd < subcircIndMax, 
                    
                        (* add subcircit seperator line  *)
                        AppendTo[gategraphics, 
                            drawSubcircSpacerLine[curCol + subSpacing/2, numQubits, dividerStyle]];
                                
                        (* add label below seperator line (unless None) *)
                        If[And[labelDrawFunc =!= None, subcircInd+1 <= Length[labels], labels[[subcircInd+1]] =!= None],
                            AppendTo[gategraphics, 
                                labelDrawFunc[labels[[subcircInd+1]], curCol + subSpacing/2]]];
                    
                        (* add offset for subcircuit spacing (avoid 0 length for visual artefact) ... *)
                        If[subSpacing > 0,
                        
                            (* if this is the penultimate subcirc and the ultimate is empty (to indicate a final schedule time),
                             * then half the offset *)
                            finalSubSpacing = If[(subcircInd < subcircIndMax-1) || Length@subcircs[[-1]] =!= 0, subSpacing, subSpacing/2];
                            AppendTo[qubitgraphics, 
                                drawQubitColumn[prevIsSpecialSwap, prevSpecialQubits, numQubits, curCol, finalSubSpacing]];
                            curCol = curCol + finalSubSpacing
                        ];
                    ]
                    ,
                    {subcirc, subcircs}
                ];
                
                (* if there's a remaining label, draw it and a final (otherwise superfluous) divider *)
                If[And[labelDrawFunc =!= None, subcircInd+1 <= Length[labels], labels[[subcircInd+1]] =!= None],
                    AppendTo[gategraphics, 
                        labelDrawFunc[labels[[subcircInd+1]], curCol + subSpacing/2]];
                    AppendTo[gategraphics, 
                        drawSubcircSpacerLine[curCol + subSpacing/2, numQubits, dividerStyle]];
                    AppendTo[qubitgraphics,
                        drawQubitColumn[False, {} , numQubits, curCol, subSpacing/2]];
                ];
                
                (* return *)
                {curCol, qubitgraphics, gategraphics}
            ]    
        ]
        
        (* renders a circuit graphics description *)
        displayCircuitGraphics[{numCols_, qubitgraphics_, gategraphics_}, opts___] :=
            Graphics[
                {
                    FaceForm[White], EdgeForm[Black],
                    qubitgraphics, gategraphics
                },
                FilterRules[{opts}, Options[Graphics]],
                ImageSize -> 30 (numCols+1),
                PlotRangePadding -> None
                (* , Method -> {"ShrinkWrap" -> True} *)
            ]
        
        (* declaring optional args to DrawCircuit *)
        Options[DrawCircuit] = {
            Compactify -> True,
            DividerStyle -> Directive[Dashed, Gray], (* None for no dividers *)
            SubcircuitSpacing -> .25,
            SubcircuitLabels -> {},
            LabelDrawer -> defaultSubcircLabelDrawer
        };
        
        (* public functions to fully render a circuit *)
        DrawCircuit[noisySched:{{_, _List, _List}..}, Repeated[numQubits_, {0,1}], opts:OptionsPattern[{DrawCircuit,Graphics}]] :=
            (* compactify each subcirc but not their union *)
            DrawCircuit[{First[#], Join @@ compactCirc[OptionValue[Compactify]] /@ Rest[#]}& /@ noisySched, numQubits, Compactify -> False, opts]
        DrawCircuit[schedule:{{_, _List}..}, numQubits_Integer, opts:OptionsPattern[]] :=
            displayCircuitGraphics[
                generateCircuitGraphics[schedule[[All,2]], numQubits, opts, SubcircuitLabels -> schedule[[All,1]], LabelDrawer -> defaultTimeLabelDrawer], opts]
        DrawCircuit[schedule:{{_, _List}..}, opts:OptionsPattern[]] :=
            DrawCircuit[schedule, getNumQubitsInCircuit[Flatten @ schedule[[All,2]]], opts]
        DrawCircuit[cols:{{___}..}, numQubits_Integer, opts:OptionsPattern[]] := 
            displayCircuitGraphics[
                generateCircuitGraphics[cols, numQubits, {}, opts], opts]
        DrawCircuit[cols:{{___}..}, opts:OptionsPattern[]] :=
            DrawCircuit[cols, getNumQubitsInCircuit[Flatten @ cols], opts]
        DrawCircuit[circ_List, args___] :=
            DrawCircuit[{circ}, args]
        DrawCircuit[___] := invalidArgError[DrawCircuit]
        
        
        
        (*
         * Below is only front-end code for drawing topology diagrams of circuits
         *)
         
        (* every gate is distinguished in 'Parameters' mode, even if differing only by parameter *)
        getTopolGateLabel["Parameters"][g_] := g
        
        (* in 'Qubits' mode, parameters are removed/ignored *)
        getTopolGateLabel["Qubits"][Subscript[C, q__][s_]] := Subscript[C, q][ getTopolGateLabel["Qubits"][s] ]
        getTopolGateLabel["Qubits"][R[_, p_]] := R[p]
        getTopolGateLabel["Qubits"][Subscript[s_, q__][__]] := Subscript[s, q]
        getTopolGateLabel["Qubits"][s_] := s
        
        (* in 'NumQubits' mode, specific qubit indices are ignored, replaced by a-z *)
        getLetterSeq[len_Integer, start_] := Sequence @@ Table[ FromLetterNumber[t], {t,start,start+len-1} ]
        getLetterSeq[list_List, start_] := getLetterSeq[Length[list], start]
        alphabetisizeGate[Subscript[C, {q__}|q__][s_]] := Subscript[C, getLetterSeq[{q},1]][ alphabetisizeGate[s, 1+Length@{q}]]
        alphabetisizeGate[Subscript[s_, {q__}|q__], i_:1] := Subscript[s, getLetterSeq[{q},i]]
        alphabetisizeGate[Subscript[s_, {q__}|q__][_], i_:1] := Subscript[s, getLetterSeq[{q},i]]
        alphabetisizeGate[R[_, p_Times], i_:1] := R[Times @@ Subscript @@@ Transpose[{(List @@ p)[[All,1]], List @ getLetterSeq[Length[p],i]}]]
        alphabetisizeGate[R[_, Subscript[p_, q_]], i_:1] := R[Subscript[p, getLetterSeq[1,i]]]
        getTopolGateLabel["NumberOfQubits"][g_] := alphabetisizeGate[g]
        
        (* in 'Gates' mode, all qubits are ignored and removed *)
        getTopolGateLabel["Gates"][Subscript[C, q__][s_]] := C[ getTopolGateLabel["Gates"][s] ]
        getTopolGateLabel["Gates"][R[_, p_Times]] := R[Row @ (List @@ p)[[All,1]]]
        getTopolGateLabel["Gates"][R[_, Subscript[p_, q_]]] := R[p]
        getTopolGateLabel["Gates"][Subscript[s_, __]|Subscript[s_, __][__]] := s
        
        (* in 'None' mode, all gate properties are discarded *)
        getTopolGateLabel["None"][s_] := None
        
        (* 'Connectivity' mode is handled entirely in DrawCircuitTopology[] *)
        
        getCircTopolGraphData[circ_, showReps_, showLocal_, groupMode_] := Module[
            {edges = {}, edgeLabels = <||>},
            
            (* for every gate ... *)
            Table[ With[
                (* extract targeted qubits, choose group/label *)
                {qubits = getSymbCtrlsTargs[gate][[{2,3}]] // Flatten},
                {label = If[groupMode === "Connectivity", 
                    Row[Sort[qubits],Spacer[.1]], 
                    getTopolGateLabel[groupMode][gate]]},
                    
                (* optionally admit single-qubit gates *)
                {vertices = If[showLocal && Length[qubits] === 1, 
                    Join[qubits, qubits],
                    qubits]},
                
                (* for every pair of targeted qubits... *)
                Table[ With[ {key = UndirectedEdge @@ Sort[pair] },
                    If[ KeyExistsQ[edgeLabels, key],
                    
                        (* if the edge exists, but the label is new (or we allow repetition), record it (else do nothing) *)
                        If[ showReps || Not @ MemberQ[edgeLabels[key], label],
                            AppendTo[edges, key];
                            AppendTo[edgeLabels[key], label]],
                            
                        (* else if the edge is new, record it unconditionally *)
                        AppendTo[edges, key];
                        edgeLabels[key] = {label}
                    ]],
                    {pair, Subsets[vertices, {2}]}
                ]],
                {gate, circ}];
                
            (* return *)
            {edges, edgeLabels}]
        
        Options[DrawCircuitTopology] = {
            ShowRepetitions -> False,
            ShowLocalGates -> True,
            DistinguishBy -> "Gates",
            DistinguishedStyles -> Automatic
        };
        
        DrawCircuitTopology[circ_List, opts:OptionsPattern[{DrawCircuitTopology, Graph, Show, LineLegend}]] := Module[
            {edges, edgeLabels, edgeIndices, graph},
            
            (* validate opt args *)
            
            (* extract topology data from circuit *)
            {edges, edgeLabels} = getCircTopolGraphData[circ, 
                OptionValue[{opts,Options[DrawCircuitTopology]}, ShowRepetitions], 
                OptionValue[{opts,Options[DrawCircuitTopology]}, ShowLocalGates], 
                OptionValue[{opts,Options[DrawCircuitTopology]}, DistinguishBy]];
            
            (* maintain indices for the list of labels recorded for each edge (init to 1) *)
            edgeIndices = <| Rule @@@ Transpose[{Keys[edgeLabels], ConstantArray[1, Length[edgeLabels]]}] |>;
        
            (* prepare an undirected graph (graphical form) with place-holder styles *)
            graph = Show[ 
                Graph[
                    Table[Style[edge, STYLES[edge]], {edge,edges}],
                    (* user-overridable default Graph properties *)
                    Sequence @@ FilterRules[{opts}, Options[Graph]],     (* Sequence[] shouldn't be necessary; another MMA Graph bug, sigh! *)
                    VertexStyle -> White,
                    VertexSize -> .1,
                    VertexLabels -> Automatic],
                (* user-overridable Show options *)
                FilterRules[{opts}, Options[Show]]];
                
            (* if there are no distinguishing gate groups, remove place-holder styles and return graph *)
            If[OptionValue[DistinguishBy] === "None",
                Return[ graph /. STYLES[_] -> Automatic ]];
                
            (* otherwise...  *)
            With[
                (* prepare legend with unique labels *)
                {legLabels = DeleteDuplicates @ Flatten @ Values @ edgeLabels},
                {legStyles = If[
                        OptionValue[DistinguishedStyles] === Automatic,
                        ColorData["Rainbow"] /@ Range[0,1,If[Length[legLabels] === 1, 2 (* force single Range *), 1/(Length[legLabels]-1)]],
                        PadRight[OptionValue[DistinguishedStyles], Length[legLabels], OptionValue[DistinguishedStyles]]
                ]},
                {edgeStyles = Rule @@@ Transpose[{legLabels, legStyles}]},
                
                (* style each graph edge one by one *)
                {graphic = graph /. STYLES[edge_] :> (edgeLabels[edge][[ edgeIndices[edge]++ ]] /. edgeStyles)},
                
                (* return the styled graph with a line legend *)
                Legended[graphic,
                    LineLegend[legStyles, StandardForm /@ legLabels, 
                        Sequence @@ FilterRules[{opts}, Options[LineLegend]]]]
            ]
        ]
                
        
        
        (*
         * Below are front-end functions for 
         * generating analytic expressions from
         * circuit specifications
         *)
         
        (* generate a swap matrix between any pair of qubits *)
        getAnalSwapMatrix[qb1_, qb1_, numQb_] :=
            IdentityMatrix @ Power[2,numQb]
        getAnalSwapMatrix[qb1_, qb2_, numQb_] /; (qb1 > qb2) :=
            getAnalSwapMatrix[qb2, qb1, numQb]
        getAnalSwapMatrix[qb1_, qb2_, numQb_] := Module[
               {swap, iden, p0,l1,l0,p1, block=Power[2, qb2-qb1]},
               
               (* as per Lemma 3.1 of arxiv.org/pdf/1711.09765.pdf *)
               iden = IdentityMatrix[block/2];
               p0 = KroneckerProduct[iden, {{1,0},{0,0}}];
               l0 = KroneckerProduct[iden, {{0,1},{0,0}}];
               l1 = KroneckerProduct[iden, {{0,0},{1,0}}];
               p1 = KroneckerProduct[iden, {{0,0},{0,1}}];
               swap = ArrayFlatten[{{p0,l1},{l0,p1}}];
               
               (* pad swap matrix to full size *)
               If[qb1 > 0, 
                   swap = KroneckerProduct[swap, IdentityMatrix@Power[2,qb1]]];
               If[qb2 < numQb-1, 
                   swap = KroneckerProduct[IdentityMatrix@Power[2,numQb-qb2-1], swap]];
               swap
        ]
        
        (* build a numQb-matrix from op matrix *)
        getAnalFullMatrix[ctrls_, targs_, op_, numQb_] := Module[
            {swaps=IdentityMatrix@Power[2,numQb], unswaps, swap, newctrls, newtargs, i,j, matr},
            
            (* make copies of user lists so we don't modify *)
            unswaps = swaps;
            newctrls = ctrls;
            newtargs = targs;
            
            (* swap targs to {0,1,...} *)
            For[i=0, i<Length[newtargs], i++,
                If[i != newtargs[[i+1]],
                    swap = getAnalSwapMatrix[i, newtargs[[i+1]], numQb];
                    swaps = swap . swaps;
                    unswaps = unswaps . swap;
                    newctrls = newctrls /. i->newtargs[[i+1]];
                    newtargs = newtargs /. i->newtargs[[i+1]];
                ]
            ];
            
            (* swap ctrls to {Length[targs], Length[targs]+1, ...} *)
            For[i=0, i<Length[newctrls], i++,
                j = Length[newtargs] + i;
                If[j != newctrls[[i+1]],
                    swap = getAnalSwapMatrix[j, newctrls[[i+1]], numQb];
                    swaps = swap . swaps;
                    unswaps = unswaps . swap;
                    newctrls = newctrls /. j->newctrls[[i+1]]
                ]
            ];
            
            (* create controlled(op) *)
            matr = IdentityMatrix @ Power[2, Length[ctrls]+Length[targs]];
            matr[[-Length[op];;,-Length[op];;]] = op;
            
            (* pad to full size *)
            If[numQb > Length[targs]+Length[ctrls],
                matr = KroneckerProduct[
                    IdentityMatrix@Power[2, numQb-Length[ctrls]-Length[targs]], matr]
            ];
            
            (* apply the swaps on controlled(op) *)
            matr = unswaps . matr . swaps;
            matr
        ]
        
        (* map gate symbols to matrices *)
        getAnalGateMatrix[Subscript[H, _]] = {{1,1},{1,-1}}/Sqrt[2];
        getAnalGateMatrix[Subscript[X, _]] = PauliMatrix[1];
        getAnalGateMatrix[Subscript[X, t__]] := KroneckerProduct @@ ConstantArray[PauliMatrix[1],Length[{t}]];
        getAnalGateMatrix[Subscript[Y, _]] = PauliMatrix[2];
        getAnalGateMatrix[Subscript[Z, _]] = PauliMatrix[3];
        getAnalGateMatrix[Subscript[S, _]] = {{1,0},{0,I}};
        getAnalGateMatrix[Subscript[T, _]] = {{1,0},{0,Exp[I Pi/4]}};
        getAnalGateMatrix[Subscript[SWAP, _,_]] = {{1,0,0,0},{0,0,1,0},{0,1,0,0},{0,0,0,1}};
        getAnalGateMatrix[Subscript[U|Matr|UNonNorm, __][m_?MatrixQ]] = m;
        getAnalGateMatrix[Subscript[U|Matr|UNonNorm, __][v_?VectorQ]] = DiagonalMatrix[v];
        getAnalGateMatrix[Subscript[Ph, t__][a_]] = DiagonalMatrix[ Append[ConstantArray[1, 2^Length[{t}] - 1], Exp[I a]] ];
        getAnalGateMatrix[G[a_]] := Exp[I a] {{1,0},{0,1}};
        getAnalGateMatrix[Fac[a_]] := a {{1,0},{0,1}}; (* will not be conjugated for density matrices *)
        (* definition immediately evaluated (via =), avoiding Mathematica's unpredictable treatment of 'a' as real (see below) *)
        getAnalGateMatrix[Subscript[Rx, _][a_]] = MatrixExp[-I a/2 PauliMatrix[1]]; (* KroneckerProduct doesn't have a one-arg identity overload?? Bah *)
        getAnalGateMatrix[Subscript[Ry, _][a_]] = MatrixExp[-I a/2 PauliMatrix[2]];
        getAnalGateMatrix[Subscript[Rz, _][a_]] = MatrixExp[-I a/2 PauliMatrix[3]];
        (* delayed assignment necessitates forced posteriori substitution of a, to avoid this:
         * https://mathematica.stackexchange.com/questions/301473/matrixexp-sometimes-erroneously-assumes-variables-are-real *)
        getAnalGateMatrix[Subscript[Rx, t__][a_]] := MatrixExp[-I DUMMY/2 KroneckerProduct @@ ConstantArray[PauliMatrix[1],Length[{t}]]] /. DUMMY -> a;
        getAnalGateMatrix[Subscript[Ry, t__][a_]] := MatrixExp[-I DUMMY/2 KroneckerProduct @@ ConstantArray[PauliMatrix[2],Length[{t}]]] /. DUMMY -> a;
        getAnalGateMatrix[Subscript[Rz, t__][a_]] := MatrixExp[-I DUMMY/2 KroneckerProduct @@ ConstantArray[PauliMatrix[3],Length[{t}]]] /. DUMMY -> a;
        getAnalGateMatrix[R[a_, pauli_]] := MatrixExp[-I DUMMY/2 getAnalGateMatrix @ pauli] /. DUMMY -> a;
        getAnalGateMatrix[R[a_, paulis_Times]] := MatrixExp[-I DUMMY/2 * KroneckerProduct @@ (getAnalGateMatrix /@ List @@ paulis)] /. DUMMY -> a;
        getAnalGateMatrix[Subscript[C, __][g_]] := getAnalGateMatrix[g];
        getAnalGateMatrix[Subscript[Id, t__]] = IdentityMatrix[2^Length[{t}]];
        
        (* extract ctrls from gate symbols *)
        getAnalGateControls[Subscript[C, c_List][___]] := c
        getAnalGateControls[Subscript[C, c__][___]] := {c}
        getAnalGateControls[_] := {}
            
        (* extract targets from gate symbols *)
        getAnalGateTargets[Subscript[U|Matr|UNonNorm, t_List][_]] := t
        getAnalGateTargets[Subscript[U|Matr|UNonNorm, t__][_]] := {t}
        getAnalGateTargets[R[_, Subscript[_, t_]]] := {t}
        getAnalGateTargets[R[_, paulis_Times]] := getAnalGateTargets /@ List @@ paulis // Flatten // Reverse
        getAnalGateTargets[Subscript[C, __][g_]] := getAnalGateTargets[g]
        getAnalGateTargets[Subscript[_, t__]] := {t}
        getAnalGateTargets[Subscript[_, t__][_]] := {t}
        
        Options[CalcCircuitMatrix] = {
            AsSuperoperator -> Automatic,
            AssertValidChannels -> True
        };
        
        (* convert a symbolic circuit channel into an analytic matrix *)
        CalcCircuitMatrix[gates_List?circContainsDecoherence, numQb_Integer, OptionsPattern[]] := 
            If[OptionValue[AsSuperoperator] =!= True && OptionValue[AsSuperoperator] =!= Automatic,
                (Message[CalcCircuitMatrix::error, "The input circuit contains decoherence channels and must be calculated as a superoperator."]; $Failed),
                With[{superops = GetCircuitSuperoperator[gates, numQb, AssertValidChannels -> OptionValue[AssertValidChannels]]},
                    If[superops === $Failed,
                    (Message[CalcCircuitMatrix::error, "Could not prepare superoperator, as per the above error."]; $Failed),
                    CalcCircuitMatrix[superops, 2*numQb]]]]
        (* convert a symbolic pure circuit into an analytic matrix *)
        CalcCircuitMatrix[gates_List, numQb_Integer, OptionsPattern[]] := 
            If[OptionValue[AsSuperoperator] === True,
                With[{superops = GetCircuitSuperoperator[gates, numQb, AssertValidChannels -> OptionValue[AssertValidChannels]]},
                    If[superops === $Failed,
                    (Message[CalcCircuitMatrix::error, "Could not prepare superoperator, as per the above error."]; $Failed),
                    CalcCircuitMatrix[superops, 2*numQb]]],
                With[{matrices = getAnalFullMatrix[
                    getAnalGateControls@#, getAnalGateTargets@#, getAnalGateMatrix@#, numQb
                    ]& /@ gates},
                    If[FreeQ[matrices, getAnalGateMatrix],
                        (* handle when matrices is empty list (sometimes GetCircuitSuperoperator returns nothing, like when given only G )*)
                        If[
                            Length[matrices] === 0,
                            matrices,
                            Dot @@ Reverse @ matrices
                        ],
                        (Message[CalcCircuitMatrix::error, "Circuit contained an unrecognised or unsupported gate: " <> 
                            ToString @ StandardForm @ First @ Cases[matrices, getAnalGateMatrix[g_] :> g, Infinity]];
                        $Failed)]]]
        CalcCircuitMatrix[gates_List, opts:OptionsPattern[]] :=
            CalcCircuitMatrix[gates, getNumQubitsInCircuit[gates], opts]
        CalcCircuitMatrix[gate_, opts:OptionsPattern[]] :=
            CalcCircuitMatrix[{gate}, opts]
        CalcCircuitMatrix[___] := invalidArgError[CalcCircuitMatrix]
        

        GetCircuitGeneralised[gates_List] := With[
            {generalGates = Replace[gates, {
                (* known channels are converted to Kraus maps *)
                g:Subscript[Kraus, __][__] :> g,
                Subscript[Damp, q_][p_] :> Subscript[Kraus, q][{
                    {{1,0},{0,Sqrt[1-p]}},
                    {{0,Sqrt[p]},{0,0}}}],
                Subscript[Deph, q_][p_] :> Subscript[Kraus, q][{
                    Sqrt[1-p] PauliMatrix[0], 
                    Sqrt[p]   PauliMatrix[3]}],
                Subscript[Deph, q1_,q2_][p_] :> Subscript[Kraus, q1,q2][{
                    Sqrt[1-p] IdentityMatrix[4], 
                    Sqrt[p/3] KroneckerProduct[PauliMatrix[0], PauliMatrix[3]],
                    Sqrt[p/3] KroneckerProduct[PauliMatrix[3], PauliMatrix[0]],
                    Sqrt[p/3] KroneckerProduct[PauliMatrix[3], PauliMatrix[3]]}],
                Subscript[Depol, q_][p_] :> Subscript[Kraus, q][{
                    Sqrt[1-p] PauliMatrix[0],
                    Sqrt[p/3] PauliMatrix[1],
                    Sqrt[p/3] PauliMatrix[2],
                    Sqrt[p/3] PauliMatrix[3]}],
                Subscript[Depol, q1_,q2_][p_] :> Subscript[Kraus, q1,q2][ Join[
                    {Sqrt[1-p] IdentityMatrix[4]},
                    Flatten[ Table[
                        (* the PauliMatrix[0] Kraus operator is duplicated, insignificantly *)
                        If[n1===0 && n2===0, Nothing, Sqrt[p/15] KroneckerProduct[PauliMatrix[n1], PauliMatrix[n2]]],
                        {n1,{0,1,2,3}}, {n2,{0,1,2,3}}], 1]]],
                (* global phase and fac become a fac*identity on the first qubit *)
                G[x_] :> Subscript[U, 0][ Exp[I x] IdentityMatrix[2] ],
                Fac[x_] :> Subscript[Matr, 0][ x IdentityMatrix[2] ],  (* will not be conjugated for density matrices *)
                (* U, Matr and UNonNorm gates remain the same *)
                g:(Subscript[U|Matr|UNonNorm, q__Integer|{q__Integer}][m_]) :> g,
                (* controlled gates are turned into U of identity matrices with bottom-right submatrix *)
                Subscript[C, c__Integer|{c__Integer}][Subscript[(mg:Matr|UNonNorm), q__Integer|{q__Integer}][m_]] :> 
                    With[{cDim=2^Length[{c}], tDim=Length@m},
                        Subscript[mg, Sequence @@ Join[{q}, {c}]][
                            ArrayFlatten[{{IdentityMatrix[tDim(cDim-1)], 0}, {0, m}}]]],
                Subscript[C, c__Integer|{c__Integer}][g_] :> 
                    With[{cDim=2^Length[{c}], tDim=2^Length[getAnalGateTargets[g]]},
                        Subscript[U, Sequence @@ Join[getAnalGateTargets[g], {c}]][
                            ArrayFlatten[{{IdentityMatrix[tDim(cDim-1)], 0}, {0, getAnalGateMatrix[g]}}]]],
                (* all other symbols are treated like generic unitary gates *)
                g_ :> Subscript[U, Sequence @@ getAnalGateTargets[g]][getAnalGateMatrix[g]]
            (* replace at top level *)
            }, 1]},
            If[ FreeQ[generalGates, getAnalGateMatrix],
                generalGates,
                (Message[GetCircuitGeneralised::error, "Circuit contained an unrecognised or unsupported gate: " <> 
                    ToString @ StandardForm @ First @ Cases[generalGates, getAnalGateMatrix[g_] :> g, Infinity]];
                    $Failed)
                    ]]
        GetCircuitGeneralised[op_] := GetCircuitGeneralised[{op}]
        GetCircuitGeneralised[___] := invalidArgError[GetCircuitGeneralised]


        (* untargeted gates *)
        getGateConj[valid_] @ G[x_] :=
            If[valid, G[-x], G[-Conjugate@x]]
        getGateConj[valid_] @ Fac[x_] :=
            Fac @ Conjugate[x]

        (* real, unparameterised gates (self conjugate) *)
        getGateConj[valid_] @ g:Subscript[H|X|Z|Id|SWAP, __] :=
            g
        getGateConj[valid_] @ g:Subscript[P, __] @ x_ :=
            g

        (* Rx, Rz and Ph merely negate phase *)
        getGateConj[valid_] @ (g:Subscript[Rx|Rz|Ph, __]) @ x_ :=
            If[valid, g[-x], g[-Conjugate[x]]]

        (* conj(Y) = - Y = {G[Pi],Y}, but we choose to keep it single U gate *)
        getGateConj[valid_] @ g:Subscript[Y, q_] :=
            Subscript[U, q] @ Conjugate @ PauliMatrix @ 2

        (* conj(Ry) is target-number-parity dependent *)
        getGateConj[valid_] @ (g:Subscript[Ry, q__Integer|{q__Integer}]) @ x_ := With[
            {s = If[OddQ @ Length @ {q}, 1, -1]},
            If[valid, g[s x], g[s Conjugate[x]]]]

        (* Pauli gadget negation determined by Y parity *)
        getGateConj[valid_] @ R[x_, p:Subscript[X|Z|Id, _]] := 
            If[valid, R[-x,p], R[-Conjugate[x],p]]
        getGateConj[valid_] @ R[x_, p:Subscript[Y, _]] :=
            If[valid, R[x,p], R[Conjugate[x],p]]
        getGateConj[valid_] @ R[x_, p:Verbatim[Times][pauliOpPatt..]] := With[
            {s = If[OddQ @ Count[p, Subscript[Y,_]], 1, -1]},
            {r = If[valid, s x, s Conjugate[x]]},
            R[r, p]]

        (* S and T gates become reverse-phased Ph *)
        getGateConj[valid_] @ Subscript[T, q_] := 
            Subscript[Ph, q][-Pi/4]
        getGateConj[valid_] @ Subscript[S, q_] := 
            Subscript[Ph, q][-Pi/2]

        (* matrix operators have every element conjugated *)
        getGateConj[valid_] @ (g:Subscript[U|UNonNorm|Matr, __])[vecOrMatr_] :=
            g @ Conjugate @ vecOrMatr
        getGateConj[valid_] @ (g:Subscript[Kraus|KrausNonTP, __])[matrices_] :=
            g[Conjugate /@ matrices]

        (* controls merely wrap conjugated base gate *)
        getGateConj[valid_] @ (c:Subscript[C,__]) @ g_ := 
            c @ getGateConj[valid] @ g
        
        (* Damp, Deph are entirely real (when valid), else we assume principal Sqrts,
         * and although Depol contains Y, its superoperator/application cancels conj(Y)=-Y *)
        getGateConj[valid_] @ (g:Subscript[Damp|Deph|Depol, __]) @ x_ :=
            If[valid, g[x], g @ Conjugate @ x]

        (* unmatched operators *)
        getGateConj[valid_][g_] := Message[GetCircuitConjugated::error,
            "Cannot obtain conjugate of unrecognised or unsupported operator: " <>
            ToString @ StandardForm @ g]

        Options[GetCircuitConjugated] = {
            AssertValidChannels -> True
        };

        (* circuit conjugate = conjugate of each gate, aborting if any unrecognised *)
        GetCircuitConjugated[circ_List?isCircuitFormat, OptionsPattern[]] :=
            Enclose[
                getGateConj[OptionValue @ AssertValidChannels] /@ circ // Flatten // ConfirmQuiet,
                (ReleaseHold @ # @ "HeldMessageCall"; $Failed) &]

        GetCircuitConjugated[gate_?isCircuitFormat, opts___] :=
            GetCircuitConjugated[{gate}, opts]

        GetCircuitConjugated[___] := invalidArgError[GetCircuitConjugated]


        (* rules to simplify operators when AssertValidChannels -> True *)
        (* note we do not simplify/assert real-parameterised gates like rotations, out of laziness *)
        assertReal[x_] := Element[x, Reals]
        getValidChannelAssumps @ Subscript[Damp, _][x_]    := assertReal[x] && (0 <= x <= 1)
        getValidChannelAssumps @ Subscript[Deph, _][x_]    := assertReal[x] && (0 <= x <= 1/2)
        getValidChannelAssumps @ Subscript[Deph, _,_][x_]  := assertReal[x] && (0 <= x <= 3/4)
        getValidChannelAssumps @ Subscript[Depol, _][x_]   := assertReal[x] && (0 <= x <= 3/4)
        getValidChannelAssumps @ Subscript[Depol, _,_][x_] := assertReal[x] && (0 <= x <= 15/16)
        
        (* un-targeted operators merge with their conjugate *)
        getSuperOpCirc[numQb_,valid_] @ G[x_] :=
            {If[valid, Nothing, G[2 I Im[x]]]}
        getSuperOpCirc[numQb_,valid_] @ Fac[x_] :=
            {Fac[x]} (* NOT Fac[Abs[x^2]] because Fac is NOT simply x * Id; it only ever left-multiplies onto states *)
        
        (* Kraus matrices become a single superop Matr *)
        getSuperOpCirc[numQb_,valid_] @ Subscript[Kraus|KrausNonTP, q__Integer|{q__Integer}] @ matrs_List := With[
            {supermatr = Total[(KroneckerProduct[Conjugate[#], #]&) /@ matrs]},
            {Subscript[Matr, q, Sequence @@ ({q} + numQb)] @ supermatr}]

        (* Damp, Depol, Deph must first be generalised to Kraus, then recursed upon... *)
        getSuperOpCirc[numQb_,valid_] @ g:Subscript[Damp|Deph|Depol, q__][x_] := With[
            {supers = getSuperOpCirc[numQb, valid] /@ GetCircuitGeneralised @ g},
            {assumps = getValidChannelAssumps @ g},
            (* and the result is optionally simplified, if CPTP condition is possible (else caller Aborts) *)
            If[valid && assumps === False, Message[GetCircuitSuperoperator::error, 
                "One or more channels could not be asserted as completely positive and trace-preserving (CPTP) and ergo could not be simplified. " <>
                "Prevent this error with AssertValidChannels -> False."]];
            If[valid, Simplify[supers, assumps], supers]]

        (* Matr are unchanged *)
        getSuperOpCirc[numQb_,valid_] @ g:Subscript[Matr, __][_] :=
            g

        (* all other gates are concatenated with their conjugated and shifted selves *)
        getSuperOpCirc[numQb_,valid_] @ g_ :=
            {g, retargetGate[q_ :> q+numQb] @ getGateConj[valid] @ g}

        Options[GetCircuitSuperoperator] = {
            AssertValidChannels -> True
        };

        GetCircuitSuperoperator[circ_List?isCircuitFormat, numQb_Integer, OptionsPattern[]] :=
            Enclose[
                (* map each gate to a superoperator(s) *)
                getSuperOpCirc[numQb, OptionValue @ AssertValidChannels] /@ circ // Flatten // ConfirmQuiet,

                (* and abort immediately if any call fails, and hijack the error message *)
                (Message[GetCircuitSuperoperator::error, #["HeldMessageCall"][[1,2]]]; $Failed) &]

        GetCircuitSuperoperator[circ_List?isCircuitFormat, opts:OptionsPattern[]] := 
            GetCircuitSuperoperator[circ, getNumQubitsInCircuit[circ], opts]

        GetCircuitSuperoperator[gate_?isCircuitFormat, args___] :=
            GetCircuitSuperoperator[{gate}, args]

        GetCircuitSuperoperator[___] := invalidArgError[GetCircuitSuperoperator]
        
        
        
        (*
         * Below are front-end functions for 
         * modifying circuits to capture device
         * constraints and noise
         *)
         
        (* divide circ into columns, filling the left-most first *)
        GetCircuitColumns[{}] := {}
        GetCircuitColumns[circ_List] := With[{
            numQb=getNumQubitsInCircuit[circ],
            numGates=Length[circ]},
            Module[{
                gates=circ, column={}, index=1, nextIndex=Null,
                available=ConstantArray[True,numQb], compactified={}, 
                qb, i},
                
                (* continue until all gates have been grouped into a column *)
                While[index <= numGates,
                    
                    (* visit each gate from start index or until column is full (no qubits available) *)
                    For[i=index, (And[i <= numGates, Not[And @@ Not /@ available]]), i++,
                    
                        (* skip Null-marked gates (present in a previous column) *)
                        If[gates[[i]] === Null, Continue[]];
                        
                        (* extract all target and control qubits of gate (indexed from 1) *)
                        qb = 1 + Flatten @ getSymbCtrlsTargs[gates[[i]]][[{2,3}]];
                        
                        If[
                            (* if all of the gate's qubits are so far untouched in this column... *)
                            And @@ available[[qb]],
                            
                            ( (* then add the gate to the column *)
                            available[[qb]] = False;
                            AppendTo[column, gates[[i]]];
                            gates[[i]] = Null;
                            ),
                            
                            ( (* otherwise mark all the gate's qubits as unavailable (since they're blocked by this gate) *)
                            available[[qb]] = False;
                            (* and if this was the first not-in-column gate, mark for next start index *)
                            If[nextIndex === Null, nextIndex=i];
                            )
                        ]
                    ];
                    
                    (* nextIndex is unchanged if a gate occupies all qubits *)
                    If[nextIndex === Null, nextIndex=index+1];
                    
                    (* finalize the new column; empty column can arise from a trailing iteration by above edge-case *)
                    AppendTo[compactified, If[column =!= {}, column, Nothing]];
                    column = {};
                    available = ConstantArray[True,numQb];
                    index = nextIndex;
                    nextIndex = Null;
                ];
                
                (* return new gate ordering, grouped into column sub-lists *)
                compactified
            ]
        ]
            
        (* the symbolic conditions (list) under which times is monotonically increasing (and real, >0) *)
        getMotonicTimesConditions[times_List] :=
            Join[
                MapThread[Less, {Most @ times, Rest @ times} ],
                GreaterEqualThan[0] /@ times,
                (Element[#,Reals]&) /@ times]
            
        areMonotonicTimes[times_List] := 
            If[(* times must be real (else symbolic) to continue *)
                AnyTrue[(Element[#, Reals]&) /@ times, (# === False &)],
                False,
                With[{conds = getMotonicTimesConditions[times]},
                    And[
                        (* adjacent numbers increase *)
                        Not @ MemberQ[conds, False], 
                        (* symbolic numbers MAY increase (it's not impossible for them to be monotonic) *)
                        Not[False === Simplify[And @@ conds]]]]]
                        
        replaceTimeDurSymbols[expr_, spec_, timeVal_, durVal_:None] := (
            expr /. If[
                (* substitute dur value first, since it may become time dependent *)
                KeyExistsQ[spec, DurationSymbol] && durVal =!= None,
                spec[DurationSymbol] -> durVal, {}
            ] /. If[
                KeyExistsQ[spec, TimeSymbol],
                spec[TimeSymbol] -> timeVal, {}]
        )
            
        (* determines subcircuit duration, active noise and passive noise of 
         * a sub-circuit, considering the circuit variables and updating them *)
        getDurAndNoiseFromSubcirc[subcirc_, subcircTime_, spec_, forcedSubcircDur_:None] := Module[
            {activeNoises={}, passiveNoises={}, gateDurs={}, subcircDur,
             qubitActiveDurs = ConstantArray[0, spec[NumTotalQubits]], slowestGateDur},
             (* note that the final #hidden qubits of qubitActiveDurs is never non-zero *)
            
            (* iterating gates in order of appearence in subcircuit... *)
            Do[ 
                With[
                    (* determine target & control qubits *)
                    {gateQubits = Flatten @ getSymbCtrlsTargs[gate][[{2,3}]]},
                    (* attempt to match the gate against the dev spec *)
                    {gateProps = With[
                        {attemptProps = Replace[gate, spec[Gates]]},
                        Which[
                            (* if no match, throw top-level error *)
                            attemptProps === gate,
                            Throw[
                                Message[InsertCircuitNoise::error, "Encountered gate " <> ToString@StandardForm@gate <> 
                                    " which is not supported by the given device specification. Note this may be due to preceding gates," <> 
                                    " if the spec contains constraints which depend on dynamic variables. See ?GetUnsupportedGates."];
                                $Failed],
                            (* if match, but targeted qubits don't exist, throw top-level error *)
                            Not @ AllTrue[gateQubits, LessThan[spec[NumAccessibleQubits]]],
                            Throw[
                                Message[InsertCircuitNoise::error, "The gate " <> ToString@StandardForm@gate <> 
                                    " involves qubits which do not exist in the given device specification. Note that hidden qubits cannot be targeted." <> 
                                    " See ?GetUnsupportedGates."];
                                $Failed],
                            (* otherwise, gate is valid and supported by dev-spec *)
                            True,
                            attemptProps]]},
                    (* work out gate duration (time and var dependent) *)
                    {gateDur = replaceTimeDurSymbols[gateProps[GateDuration], spec, subcircTime]},    
                    (* work out active noise (time, dur and var dependent) *)
                    {gateActive = replaceTimeDurSymbols[gateProps[NoisyForm], spec, subcircTime, gateDur]},
                    (* work out var-update function (time and dur dependent) *)
                    {gateVarFunc = If[KeyExistsQ[gateProps, UpdateVariables],
                        replaceTimeDurSymbols[gateProps[UpdateVariables], spec, subcircTime, gateDur],
                        Function[None]]},
                    
                    (* collect gate info *) 
                    AppendTo[activeNoises, gateActive];
                    AppendTo[gateDurs, gateDur];
                    
                    (* update circuit variables (time, dur, var dependent, but not fixedSubcircDur dependent) *)
                    gateVarFunc[];
                    
                    (* record how long the involved qubits were activated (to later infer passive dur) *)
                    qubitActiveDurs[[ 1 + gateQubits ]] = gateDur;
                ],
                {gate,subcirc}];
                
            (* infer the whole subcircuit duration (unless forced) *)
            slowestGateDur = Max[gateDurs];
    
            (* warn if duration was forced and too short *)
            If[forcedSubcircDur =!= None && forcedSubcircDur < slowestGateDur,
                Message[InsertCircuitNoise::error, 
                    "The given circuit schedule allocated insufficient time for a column's slowest gate to execute. If this is intentional, silence this warning with Quiet[]."]];
            
            (* choose the forced duration if given, else the slowest gate duration *)
            subcircDur = If[
                forcedSubcircDur === None,
                slowestGateDur,
                forcedSubcircDur];
            (* note slowestGateDur is returned even if overriden here, for schedule-checking functions *)
                
            (* iterate all qubits (including hidden) from index 0, upward *)
            Do[
                With[
                    {qubitProps = Replace[qubit, spec[Qubits]]},
                    (* continue only if qubit matches a rule in spec[Qubits] (don't noise unspecified qubits) *)
                    If[
                        qubitProps =!= qubit,
                        With[
                            (* work out start-time and duration of qubit's passive noise (pre-determined) *)
                            {passiveTime = subcircTime + qubitActiveDurs[[ 1 + qubit ]]},
                            {passiveDur = subcircDur - qubitActiveDurs[[ 1 + qubit ]]},
                            (* work out passive noise (time, dur and var dependent *)
                            {qubitPassive = replaceTimeDurSymbols[qubitProps[PassiveNoise], spec, passiveTime, passiveDur]},
                            (* work out var-update function (time and dur dependent *)
                            {qubitVarFunc = If[KeyExistsQ[qubitProps, UpdateVariables],
                                replaceTimeDurSymbols[qubitProps[UpdateVariables], spec, passiveTime, passiveDur],
                                Function[None]]},
                                
                            (* collect qubit info *) 
                            AppendTo[passiveNoises, qubitPassive];
                            
                            (* update circuit variables (can be time, var, dur, and fixedSubcircDur dependent) *)
                            qubitVarFunc[]]]
                ],    
                {qubit, 0, spec[NumTotalQubits]-1}];
        
            (* return. Note slowestGateDur is returned even when subcircDur overrides, 
             * since that info is useful to schedule-check utilities *)
            {slowestGateDur (* subcircDur *), activeNoises, passiveNoises}
        ]
        
        getSchedAndNoiseFromSubcircs[subcircs_, spec_] := Module[
            {subcircTimes={}, subcircActives={}, subcircPassives={},
             curTime, curDur, curActive, curPassive},
                
            (* initialise circuit variables *)
            curTime = 0;
            If[KeyExistsQ[spec, InitVariables],
                spec[InitVariables][]];
            
            Do[
                (* get each subcirc's noise (updates circuit variables) *)
                {curDur, curActive, curPassive} = getDurAndNoiseFromSubcirc[sub, curTime, spec];
                    
                (* losing info here (mering separate gate infos into subcirc-wide) *)
                AppendTo[subcircTimes, curTime];
                AppendTo[subcircActives, Flatten[curActive]];
                AppendTo[subcircPassives, Flatten[curPassive]];
                
                (* keep track of the inferred schedule time *)
                curTime += curDur,
                {sub, subcircs}
            ];
            
            (* append the final time to the end of the schedule *)
            AppendTo[subcircTimes, curTime];
            AppendTo[subcircActives, {}];
            AppendTo[subcircPassives, {}];
            
            (* return *)    
            {subcircTimes, subcircActives, subcircPassives}
        ]
        
        getNoiseFromSched[subcircs_, subcircTimes_, spec_] := Module[
            {subcircActives={}, subcircPassives={}, subcircDurs=Differences[subcircTimes],
             dummyDur, curActive, curPassive},
             
            (* initialise circuit variables *)
            If[KeyExistsQ[spec, InitVariables],
                spec[InitVariables][]];
            
            (* if the first subcirc isn't scheduled at time=0, start with passive noise round.
             * the caller must determine this occurred (since the returned arrays are now one-item longer) *) 
            If[ First[subcircTimes] =!= 0, 
                {dummyDur, curActive, curPassive} = getDurAndNoiseFromSubcirc[{}, 0, spec, First[subcircTimes]];
                AppendTo[subcircActives, Flatten[curActive]];
                AppendTo[subcircPassives, Flatten[curPassive]];
            ];
            
            Do[
                (* get each subcirc's noise (updates circuit variables) *)
                {dummyDur, curActive, curPassive} = getDurAndNoiseFromSubcirc[subcircs[[i]], subcircTimes[[i]], spec,
                    (* force subcirc durations based on schedule, except for the final unconstrained subcirc *)
                    If[i > Length[subcircDurs], None, subcircDurs[[i]]]];
                
                AppendTo[subcircActives, Flatten[curActive]];
                AppendTo[subcircPassives, Flatten[curPassive]]; ,
                {i, Length[subcircTimes]}
            ];
            
            (* return *)    
            {subcircActives, subcircPassives}
        ]
        
        getCondsForValidSchedDurs[spec_, subcircs_, subcircTimes_] := Module[
            {forcedSubcircDurs = Differences[subcircTimes], minSubcircDur,
             dummyActive, dummyPassive, conds},
            
            (* initialise circuit variables *)
            If[KeyExistsQ[spec, InitVariables],
                spec[InitVariables][]];
            
            (* for all but the final (irrelevant) subcircuit... *)
            conds = Table[
                (* find the slowest gate (duration possibly dependent on time, 
                 * previous passive durations and vars (which are updated) *)
                {minSubcircDur, dummyActive, dummyPassive} = getDurAndNoiseFromSubcirc[ (* throws *)
                    subcircs[[i]], subcircTimes[[i]], spec, forcedSubcircDurs[[i]]];
                (* and condition that its faster than the forced subcircuit duration *)
                Function[{small, big},
                    (* if both values are numerical... *)
                    If[ NumberQ[small] && NumberQ[big],
                        (* then we need to add wiggle room for precision *)
                        Or[small <= big, Abs @ N[big-small] < 100 $MachineEpsilon],
                        (* otherwise we make a symbolic inequality *)
                        small <= big]
                ][minSubcircDur, forcedSubcircDurs[[i]]],
                {i, Length[forcedSubcircDurs]}
            ];
            
            (* by here, the validity of subcircTimes has been determined since 
             * it does not depend at all on the final subcircuit (only the durations
             * of the preceding subcircuits). However, we pass the final subcircuit 
             * to getDurAndNoiseFromSubcirc[] so that it can be checked for its general 
             * validity (gates, qubit indices, etc) and potentially throw an error. *)
             getDurAndNoiseFromSubcirc[Last@subcircs, Last@subcircTimes, spec]; (* throws *)
             
             (* return the conds *)
             conds
        ]
            
        CheckCircuitSchedule[sched:{{_, _List}..}, spec_Association] /; Not[areMonotonicTimes[sched[[All,1]]]] := (
            Message[CheckCircuitSchedule::error, "The given schedule times are not motonically increasing, nor can be for any assignment of symbols, or they are not real and positive."];
            $Failed) 
        (* this is currently naive, and assumes each sub-circuit is valid (contains simultaneous gates), and 
         * that overlapping sub-circuits is invalid. A smarter function would
         * check sub-circuits contain gates on unique qubits, and check whether 
         * overlapping sub-circuits act on unique qubits (which would be ok).
         *)
        CheckCircuitSchedule[sched:{{_, _List}..}, spec_Association] := 
            Catch[
                With[
                    {times = sched[[All,1]], subcircs = sched[[All,2]]},
                    (* list of (possibly symbolic) conditions of sufficiently long subcircuit durations *)
                    {conds = getCondsForValidSchedDurs[spec, subcircs, times]}, (* throws *)
                    (* list of (possibly symbolic) assumptions implied by monotonicity of given schedule *)
                    {mono = getMotonicTimesConditions[times]},
                    (* combine the conditions with the monotonicty constraint *)
                    With[{valid=Simplify[conds, Assumptions -> mono]},
                        Which[
                            (* if any condition is broken regardless of symbols, schedule is invalid *)
                            MemberQ[valid, False], 
                                False,
                            (* if all conditions are satisfied despite symbol assignments, the schedule is valid *)
                            AllTrue[valid, TrueQ],
                                True,
                            (* otherwise return the symbolic conditions under which the schedule is valid *)
                            True,
                                DeleteCases[valid, True]
                        ]
                    ]
                ]
            ]
        CheckCircuitSchedule[___] := invalidArgError[CheckCircuitSchedule]
        
        isUnsupportedGate[spec_][gate_] := gate === (gate /. spec[Gates])
        
        GetUnsupportedGates[sched:{{_, _List}..}, spec_Association] :=
            GetUnsupportedGates[ sched[[All, 2]], spec ]
        GetUnsupportedGates[cols:{_List ..}, spec_Association] :=
            GetUnsupportedGates[#, spec]& /@ cols
        GetUnsupportedGates[circ_List, spec_Association] :=
           Select[circ, isUnsupportedGate[spec]]
        GetUnsupportedGates[___] := invalidArgError[GetUnsupportedGates]
            
        (* replace alias symbols (in gates & noise) with their circuit, in-place (no list nesting),
         * without triggering premature evaluation of the substituting values *)
        optionalReplaceAliases[False, spec_Association][in_] := in 
        optionalReplaceAliases[True, spec_Association][in_] := Module[
            {aliases, heldValues, releasedRules},
            
            (* transform alias rules into:   rule :> dummySubstitutedAlias[Hold[value]] *)
            aliases = spec[Aliases][[All, 1]];
            heldValues = dummySubstitutedAlias /@ Table[Extract[alias, 2, Hold], {alias, spec[Aliases]}];
            releasedRules = RuleDelayed @@@ Transpose[{aliases, heldValues}] // ReleaseHold;

            (* repeatedly replace aliases with their (revised) values, until all (nested) aliases are expanded *)
            FixedPoint[
                (Replace[#, releasedRules, Infinity] 
                    (* expand dummy-wrapped lists into sequences (happens when the original alias value was a Circuit or List) *)
                    /. dummySubstitutedAlias[{x___}] :> x 
                    (* expand dummy-wrapped sequences into sequences (happens when the original alias value was a single gate or a Sequence.
                     * this is actually an invalid syntax which will already break ViewDeviceSpec[], but protects Cica's existing code) *)
                    /. dummySubstitutedAlias -> Sequence &),
                in
            ]
        ]

        (* declaring optional args to GetCircuitSchedule *)
        Options[GetCircuitSchedule] = {
            ReplaceAliases -> False
        };
            
        (* assigns each of the given columns (unique-qubit subcircuits) a start-time *)
        GetCircuitSchedule[cols:{{__}..}, spec_Association, opts:OptionsPattern[]] := 
            Catch[
                With[
                    {times = First @ getSchedAndNoiseFromSubcircs[cols,spec]}, (* throws *)
                    Transpose[{times, Append[cols,{}]}] // optionalReplaceAliases[OptionValue[ReplaceAliases], spec]]]
        GetCircuitSchedule[circ_List, spec_Association, opts:OptionsPattern[]] :=
            GetCircuitSchedule[GetCircuitColumns[circ], spec, opts]
        GetCircuitSchedule[___] := invalidArgError[GetCircuitSchedule]
        
        (* declaring optional args to InsertCircuitNoise *)
        Options[InsertCircuitNoise] = {
            ReplaceAliases -> False
        };

        InsertCircuitNoise[schedule:{{_, _List}..}, spec_Association, opts:OptionsPattern[]] :=
            Catch[
                (* check up-front that schedule times are monotonic *)
                If[ Not @ areMonotonicTimes @ schedule[[All,1]],
                    Throw[
                        Message[InsertCircuitNoise::error, "The scheduled subcircuit times are not monotonic (and cannot be for any substitution of any symbolic times)."];
                        $Failed]];
                        
                (* attempt to insert noise into circuit (may throw gate/circ compatibility issues) *)
                Module[
                    {times, subcircs, actives, passives},
                    {times, subcircs} = Transpose[schedule];
                    {actives, passives} = getNoiseFromSched[subcircs, times, spec]; (* throws *)
                    
                    (* pad times with initial passive noise *)
                    If[ First[times] =!= 0, PrependTo[times, 0] ];
                    (* return { {t1,subcirc1,active1,passive1}, ...} *)
                    Transpose[{times, actives, passives}] // 
                        optionalReplaceAliases[OptionValue[ReplaceAliases], spec]]]
        InsertCircuitNoise[subcircs:{{__}..}, spec_Association, opts:OptionsPattern[]] := 
            Catch[
                Transpose[getSchedAndNoiseFromSubcircs[subcircs,spec]] (* throws *) // 
                    optionalReplaceAliases[OptionValue[ReplaceAliases], spec]]   
        InsertCircuitNoise[circ_List, spec_Association, opts:OptionsPattern[]] := 
            Catch[
                Transpose[getSchedAndNoiseFromSubcircs[GetCircuitColumns[circ],spec] (*throws *) ] // 
                    optionalReplaceAliases[OptionValue[ReplaceAliases], spec]]    
        InsertCircuitNoise[___] := invalidArgError[InsertCircuitNoise]
            
        ExtractCircuit[schedule:{{_, (_List ..)}..}] :=
            Flatten @ schedule[[All,2;;]]
        ExtractCircuit[subcircs:{_List..}] :=
            Flatten @ subcircs
        ExtractCircuit[circuit_List] :=
            circuit
        ExtractCircuit[{}] := 
            {}
        ExtractCircuit[___] := invalidArgError[ExtractCircuit]
        
        formatGateParamMatrices[circ_List] :=
            circ /. m_?MatrixQ :> MatrixForm[m]
            
        ViewCircuitSchedule[sched:{{_, Repeated[_List,{1,2}]}..}, opts:OptionsPattern[]] := With[
            {isPureCirc = Length @ First @ sched == 2},
            {isActiveOnly = And[Not[isPureCirc], Flatten[ Transpose[sched][[3]] ] == {}],
             isPassiveOnly = And[Not[isPureCirc], Flatten[ Transpose[sched][[2]] ] == {}]},
            Grid[
                Which[
                    isPureCirc,
                    Join[
                        {{"time", "gates"}},
                        Function[{t,g}, {t, Row[formatGateParamMatrices[g], Spacer[0]] }] @@@ sched],
                    isActiveOnly,
                    Join[
                        {{"time", "active noise"}},
                        Function[{t,a,p}, {t, Row[formatGateParamMatrices[a], Spacer[0]] }] @@@ sched],
                    isPassiveOnly,
                    Join[
                        {{"time", "passive noise"}},
                        Function[{t,a,p}, {t, Row[formatGateParamMatrices[p], Spacer[0]] }] @@@ sched],
                    True,
                    Join[
                        {{"time", "active noise", "passive noise"}},
                        Function[{t,a,p}, {t, 
                            Row[formatGateParamMatrices[a], Spacer[0]], 
                            Row[formatGateParamMatrices[p], Spacer[0]] }] @@@ sched]
                ],    
                opts,
                Dividers -> All,
                FrameStyle -> LightGray]]
        ViewCircuitSchedule[___] := invalidArgError[ViewCircuitSchedule]
                
        (* removes suffixes $ or $123... (etc) from all symbols in expression.
           these suffixes are expected to have appeared by Mathematica's automatic 
           variable renaming in nested scoping structs (Module[ Function[]]) *)
        tidySymbolNames[exp_] :=
            exp /. s_Symbol :> RuleCondition @ Symbol @
                StringReplace[ToString[HoldForm[s]], "$"~~Repeated[NumberString,{0,1}] -> ""]
                
        (* the gates in active noise can contain symbolic qubits that won't trigger 
         * Circuit[] evaluation. This function forces Circuit[] to a list *)
        frozenCircToList[HoldForm[Circuit[gs_Times]]] := ReleaseHold[List @@@ Hold[gs]]
        frozenCircToList[Circuit[gs_Times]] := ReleaseHold[List @@@ Hold[gs]]
        frozenCircToList[HoldForm[Circuit[g_]]] := {g}
        frozenCircToList[Circuit[g_]] := {g}
        frozenCircToList[HoldForm[gs_List]] := gs
        frozenCircToList[else_] := else
        
        (* attempt to display circuit as a column if it can be decomposed into a 
         * list (despite e.g. symbolic indices), display as is *)
        viewOperatorSeq[circ_] := With[
            {attempt = frozenCircToList[circ]},
            If[Head @ attempt === List,
                Row[attempt /. m_?MatrixQ :> MatrixForm[m], Spacer[0]],
                circ]]
                
        getHeldAssocVal[assoc_, key_] :=
            Extract[assoc, {Key[key]}, HoldForm]
        
        viewDevSpecFields[spec_, opts___] :=
            Grid[{
                {Style["Fields",Bold], SpanFromLeft},
                {"Number of accessible qubits", spec[NumAccessibleQubits]},
                {"Number of hidden qubits", spec[NumTotalQubits] - spec[NumAccessibleQubits]},
                {"Number of qubits (total)", spec[NumTotalQubits]},
                If[ KeyExistsQ[spec, TimeSymbol],
                    {"Time symbol", spec[TimeSymbol]},
                    Nothing],
                If[ KeyExistsQ[spec, DurationSymbol],
                    {"Duration symbol", spec[DurationSymbol]},
                    Nothing],
                If[KeyExistsQ[spec, InitVariables],
                    {"Variable init", spec[InitVariables]},
                    Nothing],
                {"Description", spec[DeviceDescription]}
                },
                FilterRules[{opts}, Options[Grid]],
                Dividers -> All,
                FrameStyle -> LightGray
            ] // tidySymbolNames
            
        viewDevSpecAliases[spec_, opts___] :=
            Grid[{
                {Style["Aliases",Bold], SpanFromLeft},
                {"Operator", "Definition"}
                } ~Join~ Table[
                    {
                        First[row], 
                        (* attempt to render element as spaced list *)
                        With[
                            {attemptedList = frozenCircToList @ Last @ row},
                            If[ Head[attemptedList] === List,
                                Row[attemptedList /. m_?MatrixQ :> MatrixForm[m], Spacer[0]],
                                HoldForm[attemptedList] /. m_?MatrixQ :> MatrixForm[m]
                            ]
                        ]
                    },
                    {row, List @@@ spec[Aliases]}],
                FilterRules[{opts}, Options[Grid]],
                Dividers -> All,
                FrameStyle -> LightGray
            ] // tidySymbolNames
            
        viewDevSpecActiveGates[spec_, opts___] := With[
            {showConds = Not @ FreeQ[First /@ spec[Gates], _Condition]},
            {showVars = Or @@ (KeyExistsQ[UpdateVariables] /@ Last /@ spec[Gates])},
            Grid[{
                {Style["Gates", Bold], SpanFromLeft},
                {"Gate", If[showConds,"Conditions",Nothing], "Noisy form", 
                    If[ KeyExistsQ[spec, DurationSymbol],
                        "Duration (" <> ToString@tidySymbolNames@spec[DurationSymbol] <> ")",
                        "Duration"],
                    If[showVars, "Variable update", Nothing]
                } 
                } ~Join~ Table[
                    With[
                        (*  isolate gate pattern and association *)
                        {key= First[row], props=Last[row]},
                        (* isolate gate from potential constraint *)
                        {gate=key //. c_Condition :> First[c]},
                        (* isolate potential constraints in held form *)
                        {conds=Cases[key, Verbatim[Condition][_,con_] :> HoldForm[con], {0,Infinity}, Heads -> True]},
                        {
                            gate,
                            If[showConds, Column@conds, Nothing], 
                            viewOperatorSeq @ getHeldAssocVal[props, NoisyForm], 
                            getHeldAssocVal[props, GateDuration], 
                            If[showVars, If[KeyExistsQ[props,UpdateVariables],props[UpdateVariables],""], Nothing]
                        }],
                    {row, spec[Gates]}
                ],
                FilterRules[{opts}, Options[Grid]],
                Dividers -> All,
                FrameStyle -> LightGray    
            ]  // tidySymbolNames
        ]
        
        viewDevSpecPassiveQubits[spec_, opts___] := With[
            {showVars = Or @@ (KeyExistsQ[UpdateVariables] /@ Last /@ spec[Qubits])},
            Grid[{
                {Style["Qubits", Bold], SpanFromLeft},
                {"Qubit", "Passive noise", If[showVars, "Variable update", Nothing]}
                } ~Join~ Table[
                    With[
                        {props = Replace[qubit, spec[Qubits]]},
                        {row = If[props === qubit,
                            (* show qubit with empty row for absent qubits *)
                            {qubit, "", If[showVars, "", Nothing]},
                            (* else, show its fields *)
                            {qubit,
                             viewOperatorSeq @ props[PassiveNoise] /. m_?MatrixQ :> MatrixForm[m], 
                             If[showVars, If[KeyExistsQ[props,UpdateVariables],props[UpdateVariables],""], Nothing]}]},     
                        (* insert labeled row at transition to hidden qubits *)
                        ReleaseHold @ If[qubit === spec[NumAccessibleQubits],
                            Hold[Sequence[{Style["Hidden qubits",Bold], SpanFromLeft}, row]],
                            row
                        ]
                    ],
                    {qubit, 0, spec[NumTotalQubits]-1}
                ],
                FilterRules[{opts}, Options[Grid]],
                Dividers -> All,
                FrameStyle -> LightGray 
            ] // tidySymbolNames
        ]
            
        ViewDeviceSpec[spec_Association, opts:OptionsPattern[{Grid,Column}]] := 
            Module[{view},
                Check[
                    (* get dev spec *)
                    view = Column[{
                        viewDevSpecFields[spec, opts],
                        If[KeyExistsQ[spec, Aliases] && spec[Aliases] =!= {},
                            viewDevSpecAliases[spec, opts], Nothing],
                        viewDevSpecActiveGates[spec, opts],
                        viewDevSpecPassiveQubits[spec, opts]
                        },
                        FilterRules[{opts}, Options[Column]],
                        Spacings -> {Automatic, 1}],
                    (* if errors, give warning about potential illegitimacy, and return dev spec *)
                    Echo["Note that the above errors may be illegitimate, due to premature evaluation of dynamic gate properties in the device specification. Have no fear! Device spec authors may fix this by replacing \[Rule] with \[RuleDelayed] in NoisyForm and GateDuration of Gates which feature variables.", "ViewDeviceSpec: "];
                    view
                ]
            ]    
        ViewDeviceSpec[___] := invalidArgError[ViewDeviceSpec]
        
        getDeviceSpecIssueString[spec_] := Catch[
            
            (* check top-level required keys *)
            Do[
                If[ Not @ KeyExistsQ[spec, key], 
                    Throw["Specification is missing the required key: " <> SymbolName[key] <> "."]],
                {key, {DeviceDescription, NumAccessibleQubits, NumTotalQubits, 
                       Gates, Qubits}}];
            
            (* check number of qubits *)
            Do[ 
                If[ Not @ MatchQ[spec[key], n_Integer /; n > 0 ], 
                    Throw["NumAccessibleQubits and NumTotalQubits must be positive integers."]],
                {key, {NumAccessibleQubits, NumTotalQubits}}];

            If[ spec[NumAccessibleQubits] > spec[NumTotalQubits],
                Throw["NumAccessibleQubits cannot exceed NumTotalQubits."]];
            
            (* check symbols are indeed symbols *)
            Do[
                If[ KeyExistsQ[spec, key],
                    If[ Not @ MatchQ[spec[key], _Symbol], 
                        Throw["TimeSymbol and DurationSymbol must be symbols."] ]],
                {key, {TimeSymbol, DurationSymbol}}];
                
            (* check  alias is a list of delayed rules to circuits *)
            If[ KeyExistsQ[spec, Aliases], 
                If[ Not @ MatchQ[ spec[Aliases], { (_ :>  (_Circuit | _List)) ... } ],
                    Throw["Aliases must be a list of DelayedRule, each pointing to a Circuit (or a list of operators)."]]]
                
            (* check aliases do not contain symbols *)
            If[ KeyExistsQ[spec, Aliases], 
                Do[
                    If[ KeyExistsQ[spec, key],
                        If[ Not @ FreeQ[spec[Aliases], spec[key]], 
                            Throw["Aliases (definitions or operators) must not feature TimeSymbol nor DurationSymbol; they can instead be passed as arguments to the alias operator."]]],
                    {key, {TimeSymbol, DurationSymbol}}]];
                    
            (* check alias LHS don't include conditions *)
            If[ KeyExistsQ[spec, Aliases], 
                If[ Not @ FreeQ[First /@ spec[Aliases], Condition],
                    Throw["Aliases must not include Condition in their operators (the left-hand side of RuleDelayed)."]]];
                
            (* check init-var is zero-arg function *)
            If[ KeyExistsQ[spec, InitVariables],
                If[ Not[
                    MatchQ[ spec[InitVariables], _Function ] &&
                    Quiet @ Check[ spec[InitVariables][]; True, False ] ], (* duck typed *)
                    Throw["InitVariables must be a zero-argument Function (or excluded entirely), which initialises any variables needing later modification in UpdateVariables."]]];
            
            (* check Gates and Qubits are list of RuleDelayed, to an association *)
            Do[
                (* If[ (Not @ MatchQ[spec[key], _List]) || (Not @ AllTrue[spec[key], MatchQ[RuleDelayed[_, _Association]]]), *)
                If[ Not @ MatchQ[spec[key], { (_ :>  _Association) ... }],
                    Throw["Gates and Qubits must each be a list of RuleDelayed, each pointing to an Association."]],
                {key, {Gates,Qubits}}];
                
            (* check every Gates association has required keys *)
            Do[
                If[ Not @ KeyExistsQ[assoc, key],
                    Throw["An Association in Gates is missing required key " <> SymbolName[key] <> "."]],
                {assoc, Last /@ spec[Gates]},
                {key, {NoisyForm, GateDuration}}];
                
            (* check that Gates patterns do not refer to symbols *)
            Do[
                If[ KeyExistsQ[spec, key],
                    If[ Not @ FreeQ[pattern, spec[key]],
                        Throw["The operator patterns in Gates (left-hand side of the rules) must not include the TimeSymbol or the DurationSymbol (though the right-hand side may)."]]],
                {pattern, First /@ spec[Gates]},
                {key, {TimeSymbol, DurationSymbol}}];
                
            (* check every Gates' GateDuration doesn't contain the duration symbol (self-reference) *)
            If[ KeyExistsQ[spec, DurationSymbol],  
                Do[
                    If[ Not @ FreeQ[dur, spec[DurationSymbol]],
                        Throw["A GateDuration cannot refer to the DurationSymbol, since the DurationSymbol is substituted the value of the former."]],
                    {dur, spec[Gates][[All, 2]][GateDuration] // Through}]];
            
            (* check every Qubit assoc contains required keys *)
            Do[
                If[ Not @ KeyExistsQ[assoc, PassiveNoise],
                    Throw["An association in Qubits is missing required key PassiveNoise."]],
                {assoc, Last /@ spec[Qubits]}]
                
            (* check every passive noise is a list (or Circuit, not yet evaluating) *)
            Do[
                If[ Not @ MatchQ[passive, _List|_Circuit],
                    Throw["Each PassiveNoise must be a Circuit[] or list of operators."]],
                {passive, spec[Qubits][[All, 2]][PassiveNoise] // Through}];
                
            (* check every update-vars (in Gates and Qubits assoc) is a zero-arg function *)
            Do[
                If[ KeyExistsQ[assoc, UpdateVariables],
                    If[ Not[
                        MatchQ[ assoc[UpdateVariables], _Function ] &&
                        (* calling UpdateVariables[] may generate other errors, but we care only about zero-args *)
                        Quiet @ Check[ assoc[UpdateVariables][]; True, False, Function::fpct ] ], (* duck typed *)
                        Throw["Each UpdateVariables must be a zero-argument Function (or excluded entirely)."]]],
                {assoc, Join[spec[Gates][[All,2]], spec[Qubits][[All,2]]] }];
                
            (* no detected issues *)
            None
        ]
        
        CheckDeviceSpec[spec_Association] := With[
            {issue = Quiet @ getDeviceSpecIssueString[spec]},
            If[ issue === None, 
                True,
                Message[CheckDeviceSpec::error, issue]; False]]    
        CheckDeviceSpec[___] := (
            Message[CheckDeviceSpec::error, "Argument must be a single Association."];
            $Failed)
            
        
        
        (*
         * Below are front-end functions 
         * for modifying circuits
         *)    
        
        getInverseGate[g:Subscript[H|Id|SWAP|X|Y|Z, __]] := g
        getInverseGate[(g:Subscript[Rx|Ry|Rz|Ph, __])[x_]] := g[-x]
        getInverseGate[R[x_, s_]] := R[-x, s]
        getInverseGate[Subscript[T, q_]] := Subscript[Ph, q][-Pi/4]
        getInverseGate[Subscript[S, q_]] := Subscript[Ph, q][-Pi/2]
        getInverseGate[G[x_]] := G[-x]
        getInverseGate[Fac[x_]] := Fac[1/x]
        getInverseGate[Subscript[(g:U|UNonNorm), q__][m_?MatrixQ]] := Subscript[g, q][ConjugateTranspose[m]]
        getInverseGate[Subscript[(g:U|UNonNorm), q__][v_?VectorQ]] := Subscript[g, q][Conjugate[v]]
        getInverseGate[Subscript[Matr, q__][m_?MatrixQ]] := Subscript[Matr, q][Inverse[m]]
        getInverseGate[Subscript[Matr, q__][v_?VectorQ]] := Subscript[Matr, q][1/v]
        getInverseGate[g:Subscript[C, c__][h_]] := With[
            {hInv = getInverseGate[h]},
            If[Head @ hInv =!= $Failed, 
                Subscript[C, c][hInv], 
                $Failed[g]]]
        getInverseGate[g_] := $Failed[g]

        GetCircuitInverse[circ_List] := With[
            {invs = getInverseGate /@ Reverse[circ]},
            {bad = FirstCase[invs, $Failed[g_] :> g]},
            If[bad === Missing["NotFound"],
                invs,
                (Message[GetCircuitInverse::error, "Could not determine the inverse of gate " <> ToString@TraditionalForm@bad <> "."];
                $Failed)]]
        GetCircuitInverse[___] := invalidArgError[GetCircuitInverse]
        
        tidyInds[q__] := Sequence @@ Sort@DeleteDuplicates@List@q
        tidyMatrixGate[Subscript[g:(U|Matr|UNonNorm), q_Integer][matrOrVec_]] := Subscript[g, q][Simplify @ matrOrVec]
        tidyMatrixGate[Subscript[g:(U|Matr|UNonNorm), q__Integer][matrOrVec_]] /; OrderedQ[{q}] := Subscript[g, q][Simplify @ matrOrVec]
        tidyMatrixGate[Subscript[g:(U|Matr|UNonNorm), q__Integer][matrOrVec_]] := 
            With[{order=Ordering[{q}]},
                Do[
                    If[order[[i]] =!= i, Block[{tmp}, With[
                        {q1={q}[[i]], q2={q}[[order[[i]]]]}, 
                        {s=CalcCircuitMatrix[{Subscript[SWAP, i-1,order[[i]]-1]}, Length[{q}]]},
                        {newMatr=If[MatrixQ[matrOrVec], (s . matrOrVec . s), (s . matrOrVec)]},
                        Return @ tidyMatrixGate @ Subscript[g, Sequence@@((({q} /. q1->tmp) /. q2->q1) /. tmp->q2)][newMatr]]]],
                    {i, Length[{q}]}]]
            
        (* multiply matrices with one another or with diagonal matrix vectors *)    
        multiplyMatrsOrVecs[m1_?MatrixQ, m2_?MatrixQ] := m1 . m2 // Simplify
        multiplyMatrsOrVecs[m_?MatrixQ, v_?VectorQ] := m . DiagonalMatrix[v] // Simplify
        multiplyMatrsOrVecs[v_?VectorQ, m_?MatrixQ] := DiagonalMatrix[v] . m // Simplify
        multiplyMatrsOrVecs[v1_?VectorQ, v2_?VectorQ] := v1 * v2 // Simplify

        SimplifyCircuit[circ_List] := With[{
            (*
             * establish preconditions
             *)
            initCols = GetCircuitColumns[circ] //. {
                (* convert Ph controls into targets *)
                Subscript[C, c__Integer|{c__Integer}][Subscript[Ph, t__Integer|{t__Integer}][x__]] :> Subscript[Ph, tidyInds[c,t]][x],
                (* convert S and T gates into Ph *)
                Subscript[(g:S|T), t_Integer ]:> Subscript[Ph, t][Pi / (g/.{S->2,T->4})], 
                Subscript[C, c__Integer|{c__Integer}][Subscript[(g:S|T), t_Integer]] :> Subscript[Ph, tidyInds[c,t]][Pi / (g/.{S->2,T->4})],
                (* sort qubits of general unitaries by SWAPs upon matrix *)
                g:Subscript[U|Matr|UNonNorm, q__Integer|{q__Integer}][matrOrVec_] :> tidyMatrixGate[g],
                Subscript[C, c__][g:Subscript[U|Matr|UNonNorm, q__Integer|{q__Integer}][matrOrVec_]] :> Subscript[C, tidyInds@c][tidyMatrixGate@g],
                (* sort controls of any gate *)
                Subscript[C, c__Integer|{c__Integer}][g_] :> Subscript[C, tidyInds@c][g],
                (* sort targets of target-order-agnostic gates *)
                Subscript[(g:(H|X|Y|Z|Id|SWAP|Ph|M||T|S)), t__Integer|{t__Integer}] :> Subscript[g, tidyInds@t],
                Subscript[(g:(Rx|Ry|Rz|Damp|Deph|Depol)), t__Integer|{t__Integer}][x__] :> Subscript[g, tidyInds@t][x],
                (* unpack all qubit lists *)
                Subscript[s_, {t__}] :> Subscript[s, t],
                Subscript[s_, {t__}][x_] :> Subscript[s, t][x],
                Subscript[C, c__][Subscript[s_, {t__}]] :> Subscript[C, c][Subscript[s, t]],
                Subscript[C, c__][Subscript[s_, {t__}][x_]] :> Subscript[C, c][Subscript[s, t][x]]
            }},
            (* above establishes preconditions:
                - gates within a column target unique qubits
                - qubit lists of order-agnostic gates are ordered and duplicate-free
                - qubit lists are flat (not contained in List)
                - phase gates have no control qubits
                - there are no T or S gates
                - R[x, pauli-tensor] have fixed-order tensors (automatic by Times)
                - the first global phase G[] will appear in the first column
            *)
            Module[{simpCols},
                (* 
                * repeatedly simplify circuit until static 
                *)
                simpCols = FixedPoint[ Function[{prevCols}, Module[{cols},
                    cols = prevCols;
                    (* 
                     * simplify contiguous columns
                     *)
                    cols = SequenceReplace[cols, Join[
                        (* remove adjacent idempotent operations *)
                        Join @@ Table[
                            { {a___, wrap@Subscript[gate, q__], b___}, {c___,  wrap@Subscript[gate, q__], d___} } :> Sequence[{a,b},{c,d}],
                            {gate, {H,X,Y,Z,Id,SWAP}},
                            {wrap, {Identity, Subscript[C, ctrls__]}}],
                        (* combine arguments of adjacent parameterized gates *)
                        Join @@ Table[ 
                            (* awkward With[] use to force immediate eval of 'gate' in DelayedRule *)
                            With[{gate=gateSymb}, {
                            { {a___, Subscript[gate, q__][x_], b___}, {c___, Subscript[gate, q__][y_], d___} } :> Sequence[{a,Subscript[gate, q][x+y//Simplify],b},{c,d}],
                            { {a___, Subscript[C, ctrl__][Subscript[gate, q__][x_]], b___}, {c___, Subscript[C, ctrl__][Subscript[gate, q__][y_]], d___} } :> Sequence[{a,Subscript[C, ctrl][Subscript[gate, q][x+y//Simplify]],b},{c,d}]
                            }],
                            {gateSymb, {Ph,Rx,Ry,Rz}}],
                        {
                            { {a___, R[x_,op_], b___}, {c___, R[y_,op_], d___} } :> Sequence[{a,R[x+y//Simplify,op],b},{c,d}],
                            { {a___, Subscript[C, ctrl__]@R[x_,op_], b___}, {c___, Subscript[C, ctrl__]@R[y_,op_], d___} } :> Sequence[{a,Subscript[C, ctrl]@R[x+y//Simplify,op],b},{c,d}]
                        },
                        (* multiply matrices of adjacent unitaries and Matr *)
                        (* we do not presently merge U unto neighbouring Matr *)
                        {
                            { {a___, Subscript[g:(U|Matr|UNonNorm), q__][mv1_], b___}, {c___, Subscript[g:(U|Matr|UNonNorm), q__][mv2_], d___} } :> 
                                (
                                    Sequence[{a,Subscript[g, q][multiplyMatrsOrVecs[mv2,mv1]],b},{c,d}]
                                ),
                            { {a___, Subscript[C, ctrl__]@Subscript[g:(U|Matr|UNonNorm), q__][mv1_], b___}, {c___, Subscript[C, ctrl__]@Subscript[g:(U|Matr|UNonNorm), q__][mv2_], d___} } :> Sequence[{a,Subscript[C, ctrl]@Subscript[g, q][multiplyMatrsOrVecs[mv2,mv1]],b},{c,d}]
                        },
                        (* merge all global phases *)
                        {
                            { {a___, G[x_], b___, G[y_], c___} } :> {G[x+y//Simplify], a, b, c},
                            { {a___, G[x_], b___}, infix___, {c___, G[y_], d___} } :> Sequence[{G[x+y//Simplify],a,b}, infix, {c,d}]
                        },
                        (* merge all factors *)
                        {
                            { {a___, Fac[x_], b___, Fac[y_], c___} } :> {Fac[x y //Simplify], a, b, c},
                            { {a___, Fac[x_], b___}, infix___, {c___, Fac[y_], d___} } :> Sequence[{Fac[x y //Simplify],a,b}, infix, {c,d}]
                        },
                        (* merge factors and global phases *)
                        {
                            { {a___, Fac[x_], b___, G[y_], c___} } :> {Fac[x Exp[y I] //Simplify], a, b, c},
                            { {a___, G[y_], b___, Fac[x_], c___} } :> {Fac[x Exp[y I] //Simplify], a, b, c},
                            { {a___, Fac[x_], b___}, infix___, {c___, G[y_], d___} } :> Sequence[{Fac[x Exp[y I] //Simplify],a,b}, infix, {c,d}],
                            { {a___, G[y_], b___}, infix___, {c___, Fac[x_], d___} } :> Sequence[{Fac[x Exp[y I] //Simplify],a,b}, infix, {c,d}]
                        },
                        (* merge adjacent Pauli operators *)
                        {
                            { {a___, Subscript[X, q__], b___}, {c___, Subscript[Y, q__], d___} } :> Sequence[{a,G[3 Pi/2],Subscript[Z, q],b},{c,d}],
                            { {a___, Subscript[Y, q__], b___}, {c___, Subscript[Z, q__], d___} } :> Sequence[{a,G[3 Pi/2],Subscript[X, q],b},{c,d}],
                            { {a___, Subscript[Z, q__], b___}, {c___, Subscript[X, q__], d___} } :> Sequence[{a,G[3 Pi/2],Subscript[Y, q],b},{c,d}],
                            { {a___, Subscript[Y, q__], b___}, {c___, Subscript[X, q__], d___} } :> Sequence[{a,G[Pi/2],Subscript[Z, q],b},{c,d}],
                            { {a___, Subscript[Z, q__], b___}, {c___, Subscript[Y, q__], d___} } :> Sequence[{a,G[Pi/2],Subscript[X, q],b},{c,d}],
                            { {a___, Subscript[X, q__], b___}, {c___, Subscript[Z, q__], d___} } :> Sequence[{a,G[Pi/2],Subscript[Y, q],b},{c,d}]
                        },
                        (* merge adjacent rotations with paulis *)
                        Join @@ Table[ With[{rot=First@ops, pauli=Last@ops}, {
                            { {a___, Subscript[pauli, q__], b___}, {c___, Subscript[rot, q__][x_], d___} } :> Sequence[{a,G[Pi/2],Subscript[rot, q][x+Pi],b},{c,d}],
                            { {a___, Subscript[rot, q__][x_], b___}, {c___, Subscript[pauli, q__], d___} } :> Sequence[{a,G[Pi/2],Subscript[rot, q][x+Pi],b},{c,d}]
                        }], 
                            {ops, {{Rx,X},{Ry,Y},{Rz,Z}}}]
                        
                        (* TODO: should I convert Z to Ph too in order to compound with Ph?? *)
                        (* and should controlled Z become Ph too?? *)
                        
                        (* TODO: turn Rx[2\[Pi] + eh] = G[\[Pi]] Rx[eh] ??? *)
                    ]];
                    (* 
                     * simplify single gates (at any level, even within controls)
                     *)
                    cols = cols //. {
                        (* remove empty columns *)
                        {} -> Nothing, 
                        {{}..} -> Nothing,
                        (* remove controlled gates with insides already removed *)
                        Subscript[C, __][Nothing] -> Nothing,
                        (* remove zero-parameter gates *)
                        Subscript[(Ph|Rx|Ry|Rz|Damp|Deph|Depol), __][0|0.] -> Nothing,
                        R[0|0.,_] -> Nothing,
                        G[0|0.] -> Nothing,
                        Fac[1|1.] -> Nothing,
                        Fac[x_ /; (Abs[x] === 1)] -> G[ ArcTan[Re@x, Im@x] ],
                        (* remove identity matrices (qubits are sorted) *)
                        Subscript[U|Matr|UNonNorm, q__][m_?MatrixQ] /; m === IdentityMatrix[2^Length[{q}]] -> Nothing,
                        Subscript[U|Matr|UNonNorm, q__][v_?VectorQ] /; v === ConstantArray[1, 2^Length[{q}]] -> Nothing,
                        (* simplify known parameters to within their periods *)
                        Subscript[Ph, q__][x_?NumericQ] /; Not[0 <= x < 2 Pi] :> Subscript[Ph, q]@Mod[x, 2 Pi],
                        (g:(Subscript[(Rx|Ry|Rz), q__]))[x_?NumericQ] /; Not[0 <= x < 4 Pi] :> g@Mod[x, 4 Pi],
                        R[x_?NumericQ, op_] /; Not[0 <= x < 4 Pi] :> R[Mod[x, 4 Pi], op],
                        (* convert single-target R to Rx, Ry or Rz *)
                        R[x_, op:Subscript[(X|Y|Z), q_]] :> (op[x] /. {X->Rx,Y->Ry,Z->Rz})
                    };
                    (* 
                     * simplify single gates (top-level only, cannot occur within controls) 
                     *)
                    cols = Replace[cols, {
                        (* transform param gates with Pi params *)
                        (g:(Subscript[(Rx|Ry|Rz), q__]))[Pi] :> Sequence[ G[3 Pi/2], g/.{Rx->X,Ry->Y,Rz->Z} ],
                        R[Pi, op_Times] :> Sequence[G[3 Pi/2], Sequence@@op],
                        Subscript[Ph, q_][Pi] :> Subscript[Z, q],
                        Subscript[Ph, q__][Pi] :> Subscript[C, Sequence@@Rest[{q}]][Subscript[Z, First@{q}]],
                        (* transform rotations gates with 2 Pi params *)
                        (g:(Subscript[(Rx|Ry|Rz), q__]))[2 Pi] :> G[Pi],
                        R[2 Pi, _Times] :> G[Pi]
                        (* forces top-level, inside each subcircuit *)
                        }, {2}];
                    (* 
                     * re-update circuit columns 
                     *)
                    If[cols === Nothing, cols={}];
                    cols = GetCircuitColumns @ ExtractCircuit @ cols;
                    cols
                ]], initCols];
                (*
                 * post-process the simplified columns
                 *)
                ExtractCircuit @ simpCols /. {
                    Subscript[Ph, q_][Pi/2] :> Subscript[S, q],
                    Subscript[Ph, q_][Pi/4] :> Subscript[T, q]
                    
                    (* TODO: controls?? Z gates?? *)
                }]]
        
        SimplifyCircuit[___] := invalidArgError[SimplifyCircuit]
        
        
        
        (*
         * Below are front-end functions 
         * for generating circuits for 
         * GetKnownCircuit[]
         *)
         
        GetKnownCircuit["QFT", qubits_List] := Flatten @ {
            Table[ { 
                Subscript[H, qubits[[n]]], 
                Table[Subscript[Ph, qubits[[n]],qubits[[n-m]]][Pi/2^m], {m,1,n-1}]},
                {n, Length[qubits], 1, -1}],
            Table[
                Subscript[SWAP, qubits[[q]], qubits[[-q]]], 
                {q, 1, Floor[Length[qubits]/2]}] }
        GetKnownCircuit["QFT", numQubits_Integer] :=
            GetKnownCircuit["QFT", Range[0,numQubits-1]]
            
        separateCoeffAndPauliTensor[pauli_Subscript] := {1, pauli}
        separateCoeffAndPauliTensor[prod_Times] := {
            Times@@Cases[prod, c:Except[pauliOpPatt]:>c],
            Times@@Cases[prod, p:pauliOpPatt:>p] }
        separateTermsOfPauliHamil[hamil_Plus] := 
            separateCoeffAndPauliTensor /@ (List @@ hamil)
        separateTermsOfPauliHamil[term_] := 
            {separateCoeffAndPauliTensor[term]}
        getSymmetrizedTerms[terms_List, fac_, 1] := 
            MapAt[fac # &, terms, {All, 1}]
        getSymmetrizedTerms[terms_List, fac_, 2] := With[
            {s1 = getSymmetrizedTerms[terms, fac/2, 1]}, 
            Join[Most[s1], {{2 s1[[-1,1]], s1[[-1,2]]}}, Reverse[Most[s1]]]]
        getSymmetrizedTerms[terms_List, fac_, n_?EvenQ] := 
            Block[{x, p=1/(4-4^(1/(n-1)))}, With[
                {s = getSymmetrizedTerms[terms, x, n-2]}, 
                {r = s /. x -> fac p},
                Join[r, r, s /. x -> (1-4p)fac, r, r]]]
        getTrotterTerms[terms_List, order_, reps_, time_] :=
            With[{s=getSymmetrizedTerms[terms, time/reps, order]},
                Join @@ ConstantArray[s, reps]]
                
        GetKnownCircuit["Trotter", hamil_, order_Integer, reps_Integer, time_] /; (
            order>=1 && (order===1 || EvenQ@order) && reps>=1) := 
            With[
                {terms = separateTermsOfPauliHamil @ hamil},
                {gates = (R[2 #1, #2]&) @@@ getTrotterTerms[terms, order, reps, time]},
                gates /. R[_, Subscript[Id, _Integer]] :> Nothing]
                
        GetKnownCircuit["HardwareEfficientAnsatz", reps_Integer, param_Symbol, qubits_List] := 
            Module[{i=1, ent},
                ent = Subscript[C, #[[1]]][Subscript[Z, #[[2]]]]& /@ Partition[qubits,2,1,{1,1}];
                Flatten[{
                    Table[{
                        Table[Subscript[g, q][param[i++]], {q,qubits}, {g,{Ry,Rz}}],
                        ent[[1 ;; ;; 2 ]],
                        ent[[2 ;; ;; 2 ]]
                    }, reps],
                    Table[Subscript[g, q][param[i++]], {q,qubits}, {g,{Ry,Rz}}]}]]
        GetKnownCircuit["HardwareEfficientAnsatz", reps_Integer, param_Symbol, numQubits_Integer] :=
            GetKnownCircuit["HardwareEfficientAnsatz", reps, param, Range[0,numQubits-1]]
            
        GetKnownCircuit["TrotterAnsatz", hamil_, order_Integer, reps_Integer, param_Symbol] := 
            Module[{i=1},
                GetKnownCircuit["Trotter", hamil, order, reps, 1] /. {
                    R[x_, p_] :> R[param[i++], p],
                    (g:Subscript[Rx|Ry|Rz, _])[x_] :> g[param[i++]]}]
                    
        GetKnownCircuit["LowDepthAnsatz", reps_Integer, paramSymbol_Symbol, qubits_List] := 
            Module[{i=1, pairs=Most@Partition[qubits,2,1,{1,1}]},
                Flatten @ Join[
                    Table[Subscript[Rz, q][paramSymbol[i++]], {q,qubits}],
                    Table[{
                            R[ paramSymbol[i++], Subscript[X, #1] Subscript[Y, #2] ],
                            R[ paramSymbol[i++], Subscript[Y, #1] Subscript[X, #2] ],
                            R[ paramSymbol[i++], Subscript[Y, #1] Subscript[Y, #2] ],
                            R[ paramSymbol[i++], Subscript[X, #1] Subscript[X, #2] ]
                            }& @@@
                            Join[ pairs[[1;;;;2]], pairs[[2;;;;2]] ],
                        reps]]]
        GetKnownCircuit["LowDepthAnsatz", reps_Integer, paramSymbol_Symbol, numQubits_Integer] :=
            GetKnownCircuit["LowDepthAnsatz", reps, paramSymbol, Range[0,numQubits-1]]
        GetKnownCircuit[___] := invalidArgError[GetKnownCircuit]



        (* 
         * Front-end functions for getting
         * generators of operators, in the
         * Pauli string basis
         *)

        (* functions for forceful simplification of a finite set of expressions produced within the below generators *)
        simplifyLogsInGenerator[expr_] := expr /. {
            Log[a_] + Log[b_] :> Log[a b],
            - Log[a_] :> Log[1/a],
            Log[Exp[a_]] :> a
        }
        simplifyRotationGenerator[angle_][gen_] :=
            FullSimplify[
                gen, angle \[Element] Reals, 
                TransformationFunctions -> {Automatic, simplifyLogsInGenerator}]

        (* (optionally-controlled) rotation gates are FullSimply'd, with their parameter asserted real, and have Log functions forcefully simplified *)
        getGateSimplifyFunc[{ Through @ (Subscript[C, __]|Identity) @ (Subscript[Rx|Ry|Rz, __][a_] | R[a_, __]) }] :=
            simplifyRotationGenerator[a]
        
        (* (optionally-controlled) Hadamard gates have their surds expanded *)
        getGateSimplifyFunc[{ Through @ (Subscript[C, __]|Identity) @ Subscript[H, __] }] :=
            Expand

        (* (optionally-controlled) Phase gates *)
        getGateSimplifyFunc[{ Through @ (Subscript[C, __]|Identity) @ Subscript[Ph, __][_] }] :=
            simplifyLogsInGenerator

        (* global phase is simply a Id, which is automatically achieved from combining Log functions *)
        getGateSimplifyFunc[{ G[a_] }] :=
            simplifyLogsInGenerator

        (* all other gates or entire circuits receive no automatic simplification *)
        getGateSimplifyFunc[_] :=
            Identity

        Options[CalcCircuitGenerator] = {
            TransformationFunction -> Automatic
        };

        CalcCircuitGenerator[circuit_List, opts___] /; isCircuitFormat[circuit] && circContainsDecoherence[circuit] :=
            CalcCircuitGenerator[GetCircuitSuperoperator @ circuit, opts]

        CalcCircuitGenerator[circuit_List, OptionsPattern[]] /; isCircuitFormat[circuit] := Module[
            {errFunc, simpFunc, shrunk, map, matr, str},
            errFunc = Message[CalcCircuitGenerator::error, "The above error prevented calculating the generator."]&;

            (* replace Automatic simplifying function with a gate-specific one *)
            simpFunc = OptionValue[TransformationFunction];
            If[simpFunc === Automatic, simpFunc = getGateSimplifyFunc[circuit]];

            (* compactify circuit; errors if circuit contain an invalid/unrecognised gate *)
            {shrunk, map} = Check[GetCircuitCompacted[circuit], errFunc[]; Return @ $Failed];

            (* get circuit analytic matrix; fails if circuit contains a gate with no known analytic form *)
            matr = Check[CalcCircuitMatrix @ shrunk, errFunc[]; Return @ $Failed];

            (* evaluate generator matrix; fails if MatrixLog cannot be evaluated, because e.g. matr has prohibitive zeroes *)
            matr = Check[-I MatrixLog @ matr, errFunc[]; Return @ $Failed];

            (* attempt to simplify generator matrix is circuit is a single gate recognised above *)
            matr = Check[simpFunc @ matr, errFunc[]; Return @ $Failed];
            If[Not @ MatrixQ @ matr, 
                Message[CalcCircuitGenerator::error, "The given TransformationFunction did not return a matrix."];
                Return @ $Failed];

            (* project generator matrix into Pauli strings on smallest qubits *)
            str = getPauliStringFromMatrix[matr];

            (* remap Pauli string qubits back to original circuit qubits*)
            str /. Subscript[(s:(X|Y|Z)), t__] :> Subscript[s, t /. map]
        ]

        CalcCircuitGenerator[gate_?isGateFormat, opts___] :=
            CalcCircuitGenerator[{gate}, opts]

        CalcCircuitGenerator[___] := invalidArgError[CalcCircuitGenerator]



        (*
         * front-end functions for remapping
         * qubits indices in circuits
        *)

        (* support both lists and sequences of qubits *)
        retargetQubits[qubits_, map_] :=
            qubits /. map
        retargetQubits[qubits__, map_] :=
            Sequence @@ ({qubits} /. map)

        (* remap controls and recurse upon inner gate *)
        retargetGate[map_][ Subscript[C, c__][g_] ] :=
            Subscript[C, retargetQubits[c, map]] @ retargetGate[map] @ g

        (* avoid modifying arg of parameterised gates *)
        retargetGate[map_][ Subscript[s:Damp|Deph|Depol|Kraus|KrausNonTP|Matr|P|Ph|Rx|Ry|Rz|U|UNonNorm, t__][args__] ] :=
            Subscript[s, retargetQubits[t, map]] @ args

        (* modify only the qubits of the Pauli product in R gates *)
        retargetGate[map_][ R[arg_, Subscript[s_, q__]] ] :=
            R[arg, Subscript[s, retargetQubits[q,map]]]
        retargetGate[map_][ R[arg_, Verbatim[Times][ p: Subscript[_,_] .. ]] ] :=
            R[arg, Times @@ MapThread[Subscript, {
                {p}[[All, 1]], 
                retargetQubits[{p}[[All, 2]], map]}]]

        (* no-parameter gates *)
        retargetGate[map_][ Subscript[s:H|Id|M|S|SWAP|T|X|Y|Z, t__] ] :=
            Subscript[s, retargetQubits[t, map]]

        (* no-target gates *)
        retargetGate[_][g:(Fac|G)[__]] := 
            g

        (* support recognisable custom user gates, and avoid modifying their params  *)
        retargetGate[map_][ Subscript[s_Symbol, q__] ] :=
            Subscript[s, retargetQubits[q, map]]
        retargetGate[map_][ Subscript[s_Symbol, q__][args___] ] :=
            Subscript[s, retargetQubits[q, map]] @ args
            
        (* throw error if qubits can't be identified *)
        retargetGate[_][g_] :=
            Throw["Could not identify qubits in unrecognised gate: " <> ToString @ StandardForm @ g]

        (* catch invalid maps with trigger ReplaceAll errors*)
        GetCircuitRetargeted[_, map_] /; (Head[0 /. map] === ReplaceAll) := 
            Message[GetCircuitRetargeted::error, "Failed to re-target the circuit due to the above ReplaceAll error"];
            
        GetCircuitRetargeted[circ_List, map_] := With[
            {newCirc = Catch[retargetGate[map] /@ circ]},
            If[ Not @ StringQ @ newCirc,
                newCirc,
                Message[GetCircuitRetargeted::error, newCirc];
                $Failed]]

        (* overload to accept single gate; note this restricts to integer qubit formats*)
        GetCircuitRetargeted[gate_?isGateFormat, map_] :=
            GetCircuitRetargeted[{gate}, map]

        GetCircuitRetargeted[___] := invalidArgError[GetCircuitRetargeted]
    


        GetCircuitQubits[gate_?isGateFormat] :=
            GetCircuitQubits @ {gate}
        GetCircuitQubits[circ_?isCircuitFormat] /; Head[circ] === List :=
            Reverse /@ Rest /@ getSymbCtrlsTargs /@ circ // Flatten // DeleteDuplicates
        GetCircuitQubits[___] := invalidArgError[GetCircuitQubits]



        GetCircuitCompacted[circuit_?isCircuitFormat] := Module[
            {qubits, map, out},
            qubits = GetCircuitQubits[circuit];
            If[qubits === $Failed, Return @ $Failed];
            map = MapThread[Rule, {qubits, Range @ Length @ qubits - 1}];
            {GetCircuitRetargeted[circuit, map], Reverse /@ map}
        ]
        GetCircuitCompacted[___] := invalidArgError[GetCircuitCompacted]



        (*
         * front-end functions for mapping explicit
         * parameter circuits to symbolic parameterised ones
        *)

        Options[GetCircuitParameterised] = {
            "UniqueParameters" -> False,
            "ExcludeChannels" -> True,
            "ExcludeGates" -> {}, (* list of patterns *)
            "ExcludeParameters" -> {} (* list of patterns *)
        };

        (* don't change excluded gate patterns *)
        getGateParameterised[_, exclGatesPatt_, _, g_] /; MatchQ[g, exclGatesPatt] :=
            {g, None}

        isParamInExcludeList[exclParamsPatt_, Subcript[C,__][g_]] :=
            isParamInExcludeList[exclParamsPatt, g]
        
        isParamInExcludeList[exclParamsPatt_, _[x_, ___]] :=
            MatchQ[x, exclParamsPatt]

        (* don't change excluded arg patterns *)
        getGateParameterised[r_, _, exclParamsPatt_, g_ ] /; isParamInExcludeList[exclParamsPatt, g] :=
            {g, None}

        (* re-paramaterise non-controlled gates *)
        getGateParameterised[r_, _,_, (g:Subscript[Damp|Deph|Depol|Ph|Rx|Ry|Rz, __])[x_]] := 
            {g[r], x}
        getGateParameterised[r_, _,_, (g:Fac|G)[x_]] := 
            {g[r], x}
        getGateParameterised[r_, _,_, R[x_, p_]] := 
            {R[r,p], x}

        (* re-param control gates, removing excludes *)
        getGateParameterised[r_, _, exclParamsPatt_, (c:Subscript[C,__])[g_] ] /; Not @ isParamInExcludeList[exclParamsPatt, g] := 
            With[
                {gx = getGateParameterised[r, None,None, g]},
                {c @ First @ gx, Last @ gx}]

        (* non-param gates are unmodified *)
        getGateParameterised[r_, _,_, g_] :=
            {g, None}

        GetCircuitParameterised[gate_?isGateFormat, s_Symbol, opts:OptionsPattern[]] :=
            GetCircuitParameterised[{gate}, s, opts]

        GetCircuitParameterised[circuit_?isCircuitFormat, s_Symbol, OptionsPattern[]] := Module[
            {exclGatesPatt,exclParamsPatt, paramInd,outGate,paramVal, outCircuit,outParams, newSymb,newParams,symbSubs},

            (* validate all options are recognised *)
            Check[ OptionValue @ "ExcludeChannels", Return @ $Failed];
            If[ Not @ BooleanQ @ OptionValue @ "ExcludeChannels", 
                Message[GetCircuitParameterised::error, "Option \"ExcludeChannels\" must be True or False"];
                Return @ $Failed];
            If[ Not @ BooleanQ @ OptionValue @ "UniqueParameters", 
                Message[GetCircuitParameterised::error, "Option \"UniqueParameters\" must be True or False"];
                Return @ $Failed];

            (* build patterns of excluded gates and params *)
            exclGatesPatt = OptionValue @ "ExcludeGates";
            exclParamsPatt = OptionValue @ "ExcludeParameters";
            If[ Head @ exclGatesPatt === List, 
                exclGatesPatt = Alternatives @@ exclGatesPatt];
            If[ Head @ exclParamsPatt === List, 
                exclParamsPatt = Alternatives @@ exclParamsPatt];
            If[ OptionValue @ "ExcludeChannels", 
                exclGatesPatt = exclGatesPatt | Subscript[Damp|Deph|Depol,__][_]];

            paramInd = 1;
            outCircuit = {};
            outParams = {};
            Do[
                (* conditionally insert symbolic param from each gate... *)
                {outGate, paramVal} = getGateParameterised[
                    s[paramInd], exclGatesPatt, exclParamsPatt, inGate];
                AppendTo[outCircuit, outGate];

                (* and if performed, increment the symbolic param counter *)
                If[paramVal =!= None, AppendTo[outParams, s[paramInd++] -> paramVal]],
                {inGate, circuit}];

            paramInd = 1;
            newParams = {};
            symbSubs = {};

            (* optionally merge duplicate parameter values *)
            If[ Not @ OptionValue @ "UniqueParameters",
                Do[
                    (* by creating a new temp param replacing all duplicates *)
                    newSymb = TEMPSYMBOL[paramInd++];
                    AppendTo[newParams, newSymb -> Last @ First @ group];

                    (* and recording how to substitute out the old params *)
                    AppendTo[symbSubs, Table[oldSymb -> newSymb, {oldSymb, First /@ group}]],

                    (* (enumerate rules with same value substitution) *)
                    {group, GatherBy[outParams, Last]}
                ];

                (* re-param circuit to TEMPSYMBOL *)
                outCircuit = outCircuit /. Flatten @ symbSubs;

                (* re-param circuit and subs back to user symbol*)
                outCircuit = outCircuit /. TEMPSYMBOL[i_] :> s[i];
                outParams = newParams /. TEMPSYMBOL[i_] :> s[i];
            ];

            {outCircuit, outParams}
        ]

        GetCircuitParameterised[___] := invalidArgError[GetCircuitParameterised]



        (* 
         * Front-end functions for exact
         * recompilation of unitary circuits
         *)

        addControlsToGate[newCtrls__][Subscript[C, oldCtrls__][g_]] :=
            Subscript[C, oldCtrls,newCtrls][g]
        addControlsToGate[newCtrls__][G[x_]] :=
            Subscript[Ph, newCtrls][x]
        addControlsToGate[newCtrls__][Subscript[Ph, t__][x_]] :=
            Subscript[Ph, newCtrls,t][x]
        addControlsToGate[newCtrls__][Subscript[S, t_]] :=
            Subscript[Ph, newCtrls,t][Pi/2]
        addControlsToGate[newCtrls__][Subscript[T, t_]] :=
            Subscript[Ph, newCtrls,t][Pi/4]
        addControlsToGate[newCtrls__][g_] :=
            Subscript[C, newCtrls][g]

        (*
         * recompiling to single-qubit canonical gates, and CNOT
         *)

        (* ultimate gate set of the decomposition *)
        decomposeToSingleQubitAndCNOT[g:G[_]] := {g}
        decomposeToSingleQubitAndCNOT[g:Subscript[H|S|T|X|Y|Z,_]] := {g}
        decomposeToSingleQubitAndCNOT[g:Subscript[Ph|Rx|Ry|Rz,_][_]] := {g}
        decomposeToSingleQubitAndCNOT[g:Subscript[Id,__]] := {g}
        decomposeToSingleQubitAndCNOT[g:Subscript[C,_][Subscript[X,_]]] := {g}

        (*
         * Below are analaytic decompositions of symbolic gates;
         * G, H, Ph, R, Rx, Ry,Rz, S, T, SWAP, X, Y, Z
         *)

        (* C*[G] -> Ph^(n), then recurses *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c__][G[x_]] ] :=
            decomposeToSingleQubitAndCNOT @ Subscript[Ph, c][x]

        (* 
         * C[H] -> C[X], T, H, S, Ph
         * src: https://github.com/qiskit-community/qiskit-community-tutorials/blob/master/awards/teach_me_qiskit_2018/exact_ising_model_simulation/Ising_time_evolution.ipynb
         *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c_][Subscript[H, t_]] ] :=
            {
                Subscript[Ph, t][-Pi/2], Subscript[H, t], Subscript[Ph, t][-Pi/4], 
                Subscript[C, c][Subscript[X, t]], 
                Subscript[T, t], Subscript[H, t], Subscript[S, t]
            }

        (*  C*[H] sub-optimally adds controls to above and recurses *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c1_, cRest__][Subscript[H, t_]] ] :=
            Flatten[
                decomposeToSingleQubitAndCNOT /@ 
                addControlsToGate[cRest] /@ 
                decomposeToSingleQubitAndCNOT @ 
                Subscript[C, c1] @ Subscript[H, t]
            ]

        (* SWAP -> C[X] *)
        decomposeToSingleQubitAndCNOT[ Subscript[SWAP, t1_,t2_] ] := 
            {
                Subscript[C, t1][Subscript[X, t2]], 
                Subscript[C, t2][Subscript[X, t1]], 
                Subscript[C, t1][Subscript[X, t2]]
            }

        (* 
         * C[SWAP] -> C[X], H, T, Ph
         * src: https://www.nature.com/articles/s41598-018-23764-x 
         *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c_][Subscript[SWAP, t1_,t2_]] ] := 
            {
                Subscript[C, t1][Subscript[X, t2]], Subscript[H, t1], Subscript[C, c][Subscript[X, t2]], Subscript[T, t1], 
                Subscript[Ph, t2][-Pi/4], Subscript[T, c], Subscript[C, t1][Subscript[X, t2]], Subscript[C, c][Subscript[X, t1]], 
                Subscript[T, t2], Subscript[C, c][Subscript[X, t2]], Subscript[Ph, t1][-Pi/4], Subscript[Ph, t2][-Pi/4], 
                Subscript[C, c][Subscript[X, t1]], Subscript[C, t1][Subscript[X, t2]], Subscript[H, t1], Subscript[T, t2], 
                Subscript[C, t1][Subscript[X, t2]]
            }

        (* 
         * C*[SWAP] -> C[X], C*[X], then recurses
         * src: https://quantum-journal.org/papers/q-2022-03-30-676/pdf/ 
         *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c__][Subscript[SWAP, t1_,t2_]] ] := 
            Flatten @ {
                Subscript[C, t1][Subscript[X, t2]], 
                decomposeToSingleQubitAndCNOT @ Subscript[C, c,t2][Subscript[X, t1]], 
                Subscript[C, t1][Subscript[X, t2]]
            }

        (* C*[Ph] -> many-target Ph, for convenient patterns below *)
        decomposeToSingleQubitAndCNOT[ Subscript[C,c__][Subscript[Ph,t__][x_]] ] :=
            decomposeToSingleQubitAndCNOT @ Subscript[Ph,c,t][x]

        (*
         * Ph^(2) -> Ph^(1), C[X]
         * src: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5882919/
         *)
        decomposeToSingleQubitAndCNOT[ Subscript[Ph,c_,t_][x_] ] :=
            {
                Subscript[Ph, t][x/2], Subscript[Ph, c][x/2], 
                Subscript[C, c][Subscript[X, t]], 
                Subscript[Ph, t][-x/2], 
                Subscript[C, c][Subscript[X, t]]
            }

        (* 
         * Ph^(n) sub-optimally adds controls to above and recurses 
         * TODO: optimise this via https://arxiv.org/pdf/quant-ph/0303063.pdf
         *)
        decomposeToSingleQubitAndCNOT[ Subscript[Ph,c_,t_,cRest__][x_] ] := 
            Flatten[
                decomposeToSingleQubitAndCNOT /@
                addControlsToGate[cRest] /@ 
                decomposeToSingleQubitAndCNOT @ 
                Subscript[Ph,c,t][x]
            ]

        (* C*[S] sub-optimally converts to Ph^(n)[pi/2] and uses above decomps *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c__][Subscript[S, t_]] ] :=
            decomposeToSingleQubitAndCNOT @ Subscript[Ph, c,t][Pi/2]

        (* C*[T] sub-optimally converts to Ph^(n)[pi/4] and uses above decomps *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c__][Subscript[T, t_]] ] :=
            decomposeToSingleQubitAndCNOT @ Subscript[Ph, c,t][Pi/4]

        (* R^(1) -> Rx, Ry, Rz (a base case) *)
        decomposeToSingleQubitAndCNOT[ R[x_, Subscript[sigma:(X|Y|Z), t_]] ] := 
            { Subscript[sigma /. {X->Rx,Y->Ry,Z->Rz}, t][x] }

        (*
         * R^(n) -> C[X], R^(n-1), by removing a Z, and C[X]'ing a remaining Y or Z
         * src: https://arxiv.org/abs/1906.01734
         *)
        decomposeToSingleQubitAndCNOT[ R[x_, Verbatim[Times][OrderlessPatternSequence[Subscript[Z, c_], g:Subscript[(Z|Y), t_], rest___]]] ] :=
            Flatten @ {
                Subscript[C, c][Subscript[X, t]], 
                decomposeToSingleQubitAndCNOT @ R[x, Times[g, rest]], 
                Subscript[C, c][Subscript[X, t]]
            }

        (*
         * R^(n) -> H, R^(n), where an X is replaced with Z (enabling above reduction)
         * src: https://arxiv.org/abs/1906.01734
         *)
        decomposeToSingleQubitAndCNOT[ R[x_, Verbatim[Times][OrderlessPatternSequence[Subscript[X, t_], rest___]]] ] :=
            Flatten @ {
                Subscript[H, t], 
                decomposeToSingleQubitAndCNOT @ R[x, Times[Subscript[Z, t], rest]], 
                Subscript[H, t]
            }

        (*
         * R^(n) -> Rx[+-pi/2], R^(n), where a Y is replaced with Z (enabling above reduction)
         * src: https://arxiv.org/abs/1906.01734
         *)
        decomposeToSingleQubitAndCNOT[ R[x_, Verbatim[Times][OrderlessPatternSequence[Subscript[Y, t_], rest___]]] ] :=
            Flatten @ {
                Subscript[Rx, t][Pi/2], 
                decomposeToSingleQubitAndCNOT @ R[x, Times[Subscript[Z, t], rest]], 
                Subscript[Rx, t][-Pi/2]
            }

        (*
         * C*[R^(n)] -> C*[Rx,Ry,Rz] using above decomposition (only middle gadget decomp gate is controlled)
         * src: https://quantumcomputing.stackexchange.com/questions/24122
         *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, ctrls__Integer][g:R[x_, prod_]] ] := 
            Module[{circ,ind},
                circ = decomposeToSingleQubitAndCNOT[g];
                ind = 1 + Floor[Length[circ] / 2];
                circ[[ind]] = decomposeToSingleQubitAndCNOT @ Subscript[C, ctrls] @ circ[[ind]];
                Flatten @ circ
            ]

        (* R[x, Id] -> G[-x/2] *)
        decomposeToSingleQubitAndCNOT[ R[x_, Subscript[Id,_]] ] :=
            G[-x/2]

        (* 
         * For user convenience, R[x, Id...] has the Id Pauli removed, then recurses.
         * Such gates can result from Trotterisation of GetRandomPauliString[] outputs
         *)
        decomposeToSingleQubitAndCNOT[ R[x_, Verbatim[Times][a___, Subscript[Id,_], b___]] ] :=
            decomposeToSingleQubitAndCNOT @ R[x, Times[a,b]]

        (*
         * C[Y] -> C[X], S, Ph
         * src: https://github.com/Qiskit/textbook/blob/main/notebooks/ch-gates/basic-circuit-identities.ipynb
         *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c_][Subscript[Y, t_]] ] := 
            {
                Subscript[Ph, t][-Pi/2], Subscript[C, c][Subscript[X, t]], Subscript[S, t]
            }

        (* C*[Y] sub-optimally adds controls to the above decomposition *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c1_,cRest__][Subscript[Y, t_]] ] :=
            Flatten[
                decomposeToSingleQubitAndCNOT /@ 
                addControlsToGate[cRest] /@ 
                decomposeToSingleQubitAndCNOT @ 
                Subscript[C, c1][Subscript[Y, t]]
            ]
        
        (* 
         * C[Z] -> C[X], H 
         * src: https://quantumcomputing.stackexchange.com/questions/13782
         *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c_][Subscript[Z, t_]] ] := 
            {
                Subscript[H, t], Subscript[C, c][Subscript[X, t]], Subscript[H, t]
            }

        (* 
         * CC[Z] -> C[X], T, Ph
         * src: https://arxiv.org/pdf/1612.09384.pdf
         *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c1_,c2_][Subscript[Z, t_]] ] := 
            {
                Subscript[C, c1][Subscript[X, t]], Subscript[Ph, t][-Pi/4], Subscript[C, c2][Subscript[X, t]], 
                Subscript[T, t], Subscript[C, c1][Subscript[X, t]], Subscript[Ph, t][-Pi/4], 
                Subscript[C, c2][Subscript[X, t]], Subscript[T, t], Subscript[T, c1], Subscript[C, c2][Subscript[X, c1]], 
                Subscript[T, c2], Subscript[Ph, c1][-Pi/4], Subscript[C, c2][Subscript[X, c1]]
            }
        
        (* C*[Z] sub-optimally treats Z as Ph[pi], and uses Ph^(n) decomposition *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c__][Subscript[Z, t_]] ] /; Length@{c} >= 3 :=
            decomposeToSingleQubitAndCNOT @ Subscript[Ph, c,t][Pi]

        (* 
         * CC[X] -> C[X], H, T, Ph, via pre/post-appending H onto CC[Z] decomp
         * src: https://arxiv.org/pdf/0803.2316.pdf
         *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c1_,c2_][Subscript[X, t_]] ] := 
            Flatten @ {
                Subscript[H, t],
                decomposeToSingleQubitAndCNOT @ Subscript[C,c1,c2][Subscript[Z,t]],
                Subscript[H, t]
            }

        (* 
         * CCC[X] -> C[X], G, H, Rz[+-pi/8]
         * src: https://classiq.tips/Competition/MCX_First.pdf
         *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c1_,c2_,c3_][Subscript[X, t_]] ] := 
            With[{r = Pi/8}, {
                G[r/2], Subscript[H, t], Subscript[Rz, c1][r], Subscript[Rz, c2][r], Subscript[Rz, c3][r],
                Subscript[Rz, t][r], Subscript[C, c3][Subscript[X, c2]],  Subscript[Rz, c2][-r] , 
                Subscript[C, c3][Subscript[X, c2]], Subscript[C, c2][Subscript[X, c1]], Subscript[Rz, c1][-r], 
                Subscript[C, c3][Subscript[X, c1]], Subscript[Rz, c1][r], Subscript[C, c2][Subscript[X, c1]], 
                Subscript[Rz, c1][-r], Subscript[C, c3][Subscript[X, c1]], Subscript[C, c1][Subscript[X, t]], 
                Subscript[Rz, t][-r], Subscript[C, c2][Subscript[X, t]], Subscript[Rz, t][r], 
                Subscript[C, c1][Subscript[X, t]], Subscript[Rz, t][-r], Subscript[C, c3][Subscript[X, t]],
                Subscript[Rz, t][r], Subscript[C, c1][Subscript[X, t]], Subscript[Rz, t][-r], 
                Subscript[C, c2][Subscript[X, t]], Subscript[Rz, t][r], Subscript[C, c1][Subscript[X, t]], 
                Subscript[Rz, t][-r], Subscript[C, c3][Subscript[X, t]], Subscript[H, t]
            }]

        (* C*[X] sub-optimally adds additional control qubits to above decomps, and recurses *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c1_,c2_,c3_,cRest__][Subscript[X, t_]] ] := 
            Flatten[
                decomposeToSingleQubitAndCNOT /@
                addControlsToGate[cRest] /@ 
                decomposeToSingleQubitAndCNOT @ 
                Subscript[C, c1,c2,c3][Subscript[X, t]]
            ]

        (* 
         * optimised decomposition of CC[g] -> C[X], C[v], where v^2 = g, used by C*[U], C*[Rx/Ry/Rz]
         * src: https://arxiv.org/pdf/quant-ph/9705009.pdf
         *)
        reduceTwoControlsToOne[{c1_,c2_}, v_, vDagger_] :=
            Flatten[ 
                decomposeToSingleQubitAndCNOT /@ {
                    Subscript[C, c1] @ v, 
                    Subscript[C, c2] @ Subscript[X, c1], 
                    Subscript[C, c1] @ vDagger, 
                    Subscript[C, c2] @ Subscript[X, c1], 
                    Subscript[C, c2] @ v
            }]

        (* 
         * optimised decomposition of CCC[g] -> C[X], C[v], where v^4 = g, used by C*[U], C*[Rx/Ry/Rz]
         * src: https://arxiv.org/pdf/quant-ph/9503016.pdf
         *)
        reduceThreeControlsToOne[{c1_,c2_,c3_}, v_, vDagger_] := 
            Flatten[
                decomposeToSingleQubitAndCNOT /@ {
                    Subscript[C, c3] @ v, 
                    Subscript[C, c3] @ Subscript[X, c2], 
                    Subscript[C, c2] @ vDagger, 
                    Subscript[C, c3] @ Subscript[X, c2], 
                    Subscript[C, c2] @ v, 
                    Subscript[C, c2] @ Subscript[X, c1], 
                    Subscript[C, c1] @ vDagger, 
                    Subscript[C, c3] @ Subscript[X, c1], 
                    Subscript[C, c1] @ v, 
                    Subscript[C, c2] @ Subscript[X, c1], 
                    Subscript[C, c1] @ vDagger,
                    Subscript[C, c3] @ Subscript[X, c1], 
                    Subscript[C, c1] @ v
            }]

        (*
         * C[Ry] -> C[X], Ry
         * C[Rz] -> C[X], Rz
         * src: https://arxiv.org/pdf/2203.15368.pdf
         *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c_][Subscript[s:Ry|Rz, t_][r_]] ] :=
            {
                Subscript[s, t][r/2], 
                Subscript[C, c][Subscript[X, t]], 
                Subscript[s, t][-r/2], 
                Subscript[C, c][Subscript[X, t]]
            }

        (*
         * C[Rx] -> C[X], Ry, Rz[+-pi/2]
         * src: https://github.com/qiskit-community/qiskit-community-tutorials/blob/master/awards/teach_me_qiskit_2018/exact_ising_model_simulation/Ising_time_evolution.ipynb
         *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c_Integer][Subscript[Rx, t_Integer][r_]] ] :=
            {
                Subscript[Rz, t][Pi/2], 
                Subscript[Ry, t][r/2], 
                Subscript[C, c][Subscript[X, t]], 
                Subscript[Ry, t][-r/2], 
                Subscript[C, c][Subscript[X, t]], 
                Subscript[Rz, t][-Pi/2]
            }

        (* CC[Rx] -> C[X], C[Rx] (etc for Ry,Rz), then recurses *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c1_,c2_][(s:Subscript[Rx|Ry|Rz, t_])[x_]]] :=
            reduceTwoControlsToOne[{c1,c2}, s[x/2], s[-x/2]]

        (* CCC[Rx] -> C[X], C[Rx] (etc for Ry,Rz), then recurses *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c1_,c2_,c3_][(s:Subscript[Rx|Ry|Rz, t_])[x_]]] :=
            reduceThreeControlsToOne[{c1,c2,c3}, s[x/4], s[-x/4]]

        (* C*[Rx/Ry/Rz] sub-optimally adds additional controls to the above decomps, then recurses *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c1_,c2_,c3_,cRest__][g:Subscript[Rx|Ry|Rz, t_][x_]]] :=
            Flatten[
                decomposeToSingleQubitAndCNOT /@
                addControlsToGate[cRest] /@ 
                decomposeToSingleQubitAndCNOT @ 
                Subscript[C, c1,c2,c3] @ g
            ]

        (* Rz^(n) merely changed to a phase gadget, then recursed *)
        decomposeToSingleQubitAndCNOT[ Subscript[Rz, t__][r_] ] :=
            decomposeToSingleQubitAndCNOT @ R[r, Times @@ Map[Subscript[Z, #]&, {t}]]

        (* C*[Rz^(n)] merely changed to a controlled phase gadget, then recursed *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c__][Subscript[Rz, t__][r_]] ] :=
            decomposeToSingleQubitAndCNOT @ 
            Subscript[C, c] @
            R[r, Times @@ Map[Subscript[Z, #]&, {t}]]

        (*
         * Below are numerical decompositions of general unitary matrices;
         * U, UNonNorm
         *)

        (* 
         * U^(1)[matrix] -> {g, y, z1, z2}, where U = Ph[g] Rz[z2] Ry[y] Rz[z1]
         * src: https://quantumcomputing.stackexchange.com/questions/16256/
         *)
        getRotationAnglesFromSingleTargetU[ {{a_,b_},{c_,d_}} ] := 
            Module[
                {g,y,z1,z2,phase},
                phase = ArcTan[Re@#, Im@#]&;

                (* determine Ry angle *)
                y = If[N@a === 0., \[Pi], 2 ArcTan[Abs[b] / Abs[a]]];

                (* determine Rz angles *)
                Which[
                    N@y === 0.,
                        z1 = 0;
                        z2 = phase[d] - phase[a],
                    N@y === Pi,
                        z1 = phase[-b] - phase[c];
                        z2 = 0,
                    True,
                        z1 = phase[-b] - phase[a];
                        z2 = phase[c] - phase[a]];

                (* determine global phase *)
                g = If[N@a === 0.,
                    phase[c] + (z1-z2)/2,
                    phase[a] + (z1+z2)/2];
                {g,y,z1,z2}
            ]

        (* 
         * U^(1)[matrix] -> Ry, Rz, Ph
         * src: https://journals.aps.org/pra/pdf/10.1103/PhysRevA.52.3457
         *)
        decomposeToSingleQubitAndCNOT[ Subscript[U|UNonNorm, t_][m_?MatrixQ] ] := 
            Module[
                {g,y,z1,z2},
                {g,y,z1,z2} = getRotationAnglesFromSingleTargetU[m];

                (* remove zero-angle gates *)
                {G[g], Subscript[Rz, t][z1], Subscript[Ry, t][y], Subscript[Rz, t][z2]} /. _[0|0.] :> Nothing
            ]

        (* 
         * C[U^(1)[matrix]] -> C[X], Ry, Rz, Ph
         * src: https://arxiv.org/pdf/quant-ph/9503016.pdf
         *
         * TODO: when z1=0 (as occurs for diagonal m), the full gate is equivalent to
         * C[G Rz] which permits a decomposition with one fewer Rz than given below.
         *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c_][Subscript[U|UNonNorm, t_][m_?MatrixQ]] ] := 
            Module[
                {g,y,z1,z2},
                {g,y,z1,z2} = getRotationAnglesFromSingleTargetU[m];
                {
                    Subscript[Rz, t][(z1-z2)/2],
                    Subscript[C, c][Subscript[X, t]],
                    Subscript[Rz, t][-(z1+z2)/2], Subscript[Ry, t][-y/2],
                    Subscript[C, c][Subscript[X, t]],
                    Subscript[Ry, t][y/2], Subscript[Rz, t][z2],
                    Subscript[Ph, c][g]
                } /. _[0|0.] :> Nothing
            ]
        
        (* 
         * uniformly-controlled^(n) Ry/Rz -> C[X], Ry/Rz
         * This is used by the U^(n) -> U^(n-1) decomposition
         * src: https://arxiv.org/pdf/quant-ph/0404089.pdf
         * 
         * TODO: the optimisation described in the below paper 
         * for compactifying the diagonal-unitary decomposition
         * (similar to this; using gray-code Hadamard transform)
         * might also be possible here.
         * src: https://arxiv.org/pdf/2212.01002.pdf
         *)

        getGrayCodes[numBits_] := With[
            {codes = Nest[Join[#,Length[#]+Reverse[#]]&,{0},numBits]},
            PadLeft[#,numBits]& /@ IntegerDigits[codes, 2]]

        getGrayCodeBitFlipInds[numBits_] := With[
            {bits = Append[getGrayCodes[numBits], ConstantArray[0,numBits]]},
            Position[Abs[bits[[2;;]] - bits[[;;-2]]], 1][[All,2]]]

        getGrayCodeRenormalisedHadamardMatrix[numBits_] := With[
            {codes = getGrayCodes[numBits]},
            (1/2^numBits) Transpose @ Table[
                (-1)^(PadLeft[IntegerDigits[i-1,2],numBits] . codes[[j]]),
                {i,2^numBits},{j,2^numBits}]]

        getDecompOfUniformlyControlledRyOrRz[rot:Ry|Rz, ctrls_, targ_, angles_] := With[
            {numBits = Length[ctrls]},
            {flipInds = getGrayCodeBitFlipInds[numBits]},
            {newAngles = getGrayCodeRenormalisedHadamardMatrix[numBits] . angles},
            Flatten @ MapThread[
                {Subscript[rot, targ] @ #1, Subscript[C, #2] @ Subscript[X, targ]} &,
                {newAngles, ctrls[[-flipInds]]}]]

        (*
         * uniformly-controlled^(1) U^(n)[matrix] -> U^(n)[matrix], uniformly-controlled^(n) Rz
         * This then recurses to the above decomposition, and is used by U^(n) -> U^(n-1)
         * src: https://edu.itp.phys.ethz.ch/hs12/qsit/solutions05.pdf
         *)
        
        getSpectralDecomp[m0_, m1_] := Module[
            {diags, matrV, matrD, matrW},
            {diags, matrV} = Eigensystem[ m0 . ConjugateTranspose[m1] ];
            matrV = Transpose @ Orthogonalize[matrV, Method->"GramSchmidt"];
            matrD = Sqrt @ DiagonalMatrix @ diags;
            matrW = matrD . ConjugateTranspose[matrV] . m1;
            {matrV, matrD, matrW}
        ]
            
        getDecompOfUniformlyControlledU[m0_, m1_, ctrl_, targs_, s:U|UNonNorm] := Module[
            {mV, mD, mW, angles, circD, newOp},
            
            (* results will be erroneous if either of the input matrices are non-unitary *)
            If[(s === U) && Not[And @@ UnitaryMatrixQ /@ {m0,m1}],
                Throw["Encountered a non-unitary U gate matrix which cannot be (spectrally) decomposed. Please use UNonNorm instead."]];
            
            (* spectral-decompose U[m0,m1] into fewer-qubit mV and mW, and uniformly-controlled Rz[Diagonal@mD] *)
            {mV, mD, mW} = getSpectralDecomp[m0, m1];

            (* a zero-diagonal should be impossible if both m0 and m1 are unitarity, but it doesn't hurt to check *)
            If[MemberQ[Chop @ Diagonal @ mD, 0],
                Throw["The spectral decomposition involved in recompiling a " <> ToString@s <> " gate failed. This should never occur; please report to Tyson Jones."]];
            
            (* further decompose uniformly-controlled Rz[Diagonal@mD] into CNOTs and Rz *)
            angles = -2 (ArcTan[Re@#, Im@#]& /@ Diagonal[mD]);
            circD = getDecompOfUniformlyControlledRyOrRz[Rz, targs, ctrl, angles];
            newOp = Subscript[s, Sequence @@ targs];
            {newOp[mW], circD, newOp[mV]}
        ]

        (*
         * U^(n)[matrix] -> uniformly-controlled^(1) U^(n-1)[matrix], uniformly-controlled^(n-1) Ry
         * These are then further decomposed via the above methods, then recursed upon.
         * src: https://arxiv.org/pdf/0707.1838.pdf
         *)

        getCosineSineDecomp[m_] := Module[
            {dim, u00,u10,u01, l0,l1,d00,d10,r0,r1, angles},

            (* partition input matrix into four quadrants *)
            dim = Length[m];
            u00 = m[[;;dim/2, ;;dim/2]];
            u10 = m[[dim/2+1;;, ;;dim/2]];
            u01 = m[[;;dim/2, dim/2+1;;]];

            (* perform cosine-sine (CS) decomposition via numerical GSVD *)
            {{l0,l1},{d00,d10},r0} = SingularValueDecomposition @ N @ {u00, u10};	
            
            (* TODO: we should implement the general CS decomposition, in order to handle when 
             * the diagonals include zeros; see https://arxiv.org/abs/2302.14324
             * For now, we will just fail instead. The numerical threshold of 10^(-15)
             * (as a substitute for precisely 0) was arbitrarily chosen.
             *)
            If[Abs @ Det[d10] < 10^(-15),
                Throw["The cosine-sine decomposition involved in recompiling a U (or UNonNorm) gate failed."]];
            
            (* obtain right-hand-side uniformly-controlled matrices *)
            r0 = ConjugateTranspose[r0];
            r1 = - Inverse[d10] . ConjugateTranspose[l0] . u01;
            
            (* obtain angles of the uniformly-controlled Ry gate *)
            angles = 2 ArcCos /@ Diagonal[d00];
            
            (* return sub-matrices which together constitute:
             * m = diag(l0,l1) * {{d00, -d10}, {d10,d00}} * diag(r0,r1)
             * where angles are the diagonals of d00
             *)
            {l0,l1,r0,r1,angles}
        ]

        decomposeToSingleQubitAndCNOT[ g:Subscript[s:U|UNonNorm, t__][m_?MatrixQ] ] := Module[
            {tMost,tLast, l0,l1,r0,r1,angles, lg0,lg1,rg0,rg1, lc0,lc1,lc2,mc,rc0,rc1,rc2},
            
            (* The GSVD used by the CS-decomposition is strictly numerical *)
            If[Not @ MatrixQ[m, NumericQ],
                Throw["Encountered a non-numerical matrix in a two (or more) qubit " <> ToString@s <> " gate, which cannot be decomposed."]];
            
            (* discard identity matrix, to thwart all-control instability *)
            If[N[m] === N @ IdentityMatrix @ Length[m],
                Return @ {}];
            
            (* partition targets; each recursive call of this function removes one *)
            tMost = Most @ {t};
            tLast = Last @ {t};
            
            (* perform CS-decomposition on matrix m, yielding uniformly-controlled gates *)
            {l0,l1,r0,r1,angles} = getCosineSineDecomp @ N @ m;
            
            (* decompose the CS' uniformly-controlled Ry into CNOT + Ry *)
            mc = getDecompOfUniformlyControlledRyOrRz[Ry, tMost, tLast, angles];
            
            (* decompose away the uniform-controls on the remaining CS gates *)
            {lg0, lc1, lg1} = getDecompOfUniformlyControlledU[l0, l1, tLast, tMost, s];
            {rg0, rc1, rg1} = getDecompOfUniformlyControlledU[r0, r1, tLast, tMost, s];
            
            (* recursively decompose the leftmost and rightmost (Length[t]-1)-qubit gates of the above decomp *)
            {lc0, lc2, rc0, rc2} = decomposeToSingleQubitAndCNOT /@ {lg0,lg1,rg0,rg1};
            
            (* combine the sub-circuits *)
            Flatten @ Join[rc0, rc1, rc2, mc, lc0, lc1, lc2]
        ]

        (* C[U^(n)[matrix]] sub-optimally adds a control to the above decomp, then recurses *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c_][u:Subscript[U|UNonNorm, t__][m_?MatrixQ]] ] :=
            Flatten[
                decomposeToSingleQubitAndCNOT /@
                addControlsToGate[c] /@ 
                decomposeToSingleQubitAndCNOT @ u
            ]

        (* CC[U^(n)[matrix]] -> C[X], C[U^(n)[matrix]] then recurses *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c1_,c2_][(g:Subscript[U|UNonNorm, t__])[m_?MatrixQ]] ] := 
            With[
                {mSqrt = MatrixPower[m, 1/2]},
                reduceTwoControlsToOne[{c1,c2}, g@mSqrt, g@ConjugateTranspose@mSqrt]
            ]

        (* CCC[U^(n)[matrix]] -> C[X], C[U^(n)[matrix]] then recurses *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c1_,c2_,c3_][(g:Subscript[U|UNonNorm, t__])[m_?MatrixQ]] ] := 
            With[
                {mQdrt = MatrixPower[m, 1/4]},
                reduceThreeControlsToOne[{c1,c2,c3}, g@mQdrt, g@ConjugateTranspose@mQdrt]
            ]

        (* C*[U^(n)[matrix]] sub-optimally adds controls to the above decomps, then recurses *)
        decomposeToSingleQubitAndCNOT[ Subscript[C, c1_,c2_,c3_,cRest__][u:Subscript[U|UNonNorm, t__][m_?MatrixQ]] ] := 
            Flatten[
                decomposeToSingleQubitAndCNOT /@
                addControlsToGate[cRest] /@ 
                decomposeToSingleQubitAndCNOT @ 
                Subscript[C, c1,c2,c3] @ u
            ]

        (* U^(1)[vector] (diagonal) is automatically simplified when treated as a matrix *)
        decomposeToSingleQubitAndCNOT[ (g:Subscript[U|UNonNorm, t_])[v_?VectorQ] ] :=
            decomposeToSingleQubitAndCNOT @ g @ DiagonalMatrix @ v

        (* 
         * C*[U^(n)[vector]], i.e. diagonal unitaries, are not yet implemented,
         * but should make use use of the gray-code Hadamard-transform optimisation
         * described below, and the other compacting optimisations.
         * src: https://arxiv.org/pdf/2212.01002.pdf
         *)
        decomposeToSingleQubitAndCNOT[ Subscript[U|UNonNorm, t__][v_?VectorQ] ] :=
            Throw["Many-qubit diagonal gates are not yet supported by the recompiler."]
        decomposeToSingleQubitAndCNOT[ Subscript[C, c__][Subscript[U|UNonNorm, t__][v_?VectorQ]] ] :=
            Throw["Controlled diagonal gates are not yet supported by the recompiler."]

        (* throw error on unrecognised gate *)
        decomposeToSingleQubitAndCNOT[ g_ ] :=
            Throw["Could not recompile unrecognised gate: " <> ToString @ StandardForm @ g]

        (*
         * recompiling to Clifford gates and Rz
         *)

        (* ultimate gate set of the decomposition *)
        decomposeToCliffordAndRz[g:G[_]] := {g}
        decomposeToCliffordAndRz[g:Subscript[H|S|X|Y|Z,_]] := {g}
        decomposeToCliffordAndRz[g:Subscript[C,_][Subscript[X|Y|Z,_]]] := {g}
        decomposeToCliffordAndRz[g:Subscript[Id,__]] := {g}
        decomposeToCliffordAndRz[g:Subscript[SWAP,_,_]] := {g}
        decomposeToCliffordAndRz[g:Subscript[Rz,_][_]] := {g}

        (*
         * Rx -> H, Rz
         * src: https://quantumcomputing.stackexchange.com/questions/11861/
         *)
        decomposeToCliffordAndRz[ Subscript[Rx,t_][r_] ] := 
            {
                Subscript[H,t], Subscript[Rz,t][r], Subscript[H,t]
            }

        (*
         * Ry -> H, S, Rz
         * src: https://quantumcomputing.stackexchange.com/questions/11861/
         *)
        decomposeToCliffordAndRz[ Subscript[Ry,t_][r_] ] := 
            {
                Subscript[S,t], Subscript[H,t], Subscript[Rz,t][-r], Subscript[H,t],
                Subscript[S,t], Subscript[S,t], Subscript[S,t]
            }

        (* Ph -> G, Rz *)
        decomposeToCliffordAndRz[ Subscript[Ph,t_][r_] ] := 
            {
                G[r/2], Subscript[Rz, t][r]
            }

        (* T -> Ph, then recurse *)
        decomposeToCliffordAndRz[ Subscript[T,t_] ] :=
            decomposeToCliffordAndRz @ Subscript[Ph,t][Pi/4]

        (* sub-optimally decompile all other gates to single-qubit, then convert to Clifford *)
        decomposeToCliffordAndRz[ g_ ] :=
            Flatten[
                decomposeToCliffordAndRz /@ decomposeToSingleQubitAndCNOT[g]]

        (*
         * recompiler interface
         *)

        changeQubitListsToSeqs[circ_] :=
            circ /. Subscript[g_, {q__Integer}] :> Subscript[g, q]

        recompileCircuitInner[circ_, decompMethod_] := Module[
            {result, phase, adjusted},

            (* decompose each gate in-turn, catching errors and unrecognised gates *)
            result = Catch @ Flatten @ Table[
                With[
                    {decomp = Catch @ decompMethod @ gate},
                    If[ StringQ @ decomp,
                        Message[RecompileCircuit::error, "Recompilation failed. " <> decomp];
                        Throw @ $Failed];
                    decomp
                ],
                {gate, changeQubitListsToSeqs @ circ}
            ];
            If[result === $Failed, 
                Return @ $Failed];

            (* combine all global phases into one initial G gate *)
            phase = 0;
            adjusted = result /. G[x_] :> (phase += x; Nothing);
            If[phase === 0,
                adjusted,
                Prepend[adjusted, G[phase]]
            ]
        ]

        RecompileCircuit[gate_?isGateFormat, args___] :=
            RecompileCircuit[{gate}, args]

        RecompileCircuit[circ_?isCircuitFormat, method_?StringQ] := 
            Which[
                method === "SingleQubitAndCNOT",
                    recompileCircuitInner[circ, decomposeToSingleQubitAndCNOT],
                method === "CliffordAndRz",
                    recompileCircuitInner[circ, decomposeToCliffordAndRz],
                True,
                    Message[RecompileCircuit::error, "Unrecognised method. See available methods via ?RecompileCircuit"];
            ]

        RecompileCircuit[___] := invalidArgError[RecompileCircuit]



        (* 
         * Front-end functions for converting
         * gates and circuits between the Z-basis
         * and Pauli-basis.
         *)

        getChoiVecFromMatrix[m_] := 
            Transpose @ {Flatten @ Transpose @ m}
            
        getSuperOpInnerProd[bra_, op_, ket_] := 
            Part[ConjugateTranspose[bra] . op . ket, 1,1]

        getSuperOpPTM[super_?MatrixQ, simpFunc_] := 
            Module[{d,p},
                d = Sqrt @ Length @ super;
                (* todo: can significantly speed this up using sparsity, Hadamard-walsh transform, etc *)
                p = Table[SparseArray @ getChoiVecFromMatrix @ getNthPauliTensorMatrix[i-1, Log2@d],{i,d^2}];
                SparseArray @ Table[
                    (1/d) getSuperOpInnerProd[p[[i]], super, p[[j]]] // simpFunc,
                    {i,d^2}, {j,d^2}
                ]
            ]
            
        Options[CalcPauliTransferMatrix] = {
            AssertValidChannels -> True
        };
    
        CalcPauliTransferMatrix[circ_?isCircuitFormat, opts:OptionsPattern[]] :=
            Enclose[
                Module[
                    {simpFlag, qubits, targCirc, compCirc, superMatr, ptMatr},

                     (* trigger option validation (and show error message immediately )*)
                    simpFlag = OptionValue[AssertValidChannels];

                    (* replace global phase gates with equivalent unitary on arbitrary qubit *)
                    qubits = GetCircuitQubits[circ] // ConfirmQuiet;
                    targCirc = circ /. g:G[_] :> Subscript[U, If[qubits==={},0,Min@qubits]] @ CalcCircuitMatrix @ g;

                    (* thereafter ensure circ isn't all non-targeted Fac[] (and similar) gates *)
                    qubits = GetCircuitQubits[targCirc] // ConfirmQuiet;
                    If[qubits === {}, Message[CalcPauliTransferMatrix::error, "Circuit must explicitly target at least one qubit."]] // ConfirmQuiet;

                    (* get equivalent circuit acting upon lowest order qubits *)
                    compCirc = First @ GetCircuitCompacted[targCirc] // ConfirmQuiet;

                    (* compute superator of entire circuit (passing on AssertValidChannels) *)
                    superMatr = SparseArray @ CalcCircuitMatrix[compCirc, AsSuperoperator -> True, opts] // ConfirmQuiet;
                    If[superMatr === {}, Message[CalcPauliTransferMatrix::error, "Could not compute circuit superoperator."]] // ConfirmQuiet;

                    (* compute PTM from superoperator (and optionally simplify it) **)
                    ptMatr = getSuperOpPTM[superMatr, If[simpFlag, FullSimplify, Identity]];

                    (* return PTM[] symbol *)
                    Subscript[PTM, Sequence @@ qubits] @ ptMatr
                ],
                (* if any function call above failed... *)
                Function[{failObj},

                    (* hijack its error messages (note; invalid option error already shown *)
                    If[
                        failObj["HeldMessageName"] =!= Hold[OptionValue::nodef],
                        Message[CalcPauliTransferMatrix::error, failObj["HeldMessageCall"][[1,2]]]
                    ];
                    $Failed
                ]
            ]

        CalcPauliTransferMatrix[___] := invalidArgError[CalcPauliTransferMatrix]



        getMapOfPauliIndicesFromPTM[matr_?MatrixQ] :=
            Table[
                (i-1) ->
                With[
                    {col = matr . SparseArray @ UnitVector[Length[matr], i]},
                    {inds = Flatten @ SparseArray[col]["NonzeroPositions"]},
                    Transpose @ {inds - 1, col[[inds]]}],
                {i, Length[matr]}]


        Options[CalcPauliTransferMap] = {
            AssertValidChannels -> True
        };

        CalcPauliTransferMap[ Subscript[PTM, q__Integer][m_], OptionsPattern[] ] := (
            Check[ OptionValue[AssertValidChannels], Return @ $Failed];
            Subscript[PTMap, q] @@ getMapOfPauliIndicesFromPTM[m] )

        CalcPauliTransferMap[ Subscript[PTM, q__Integer][m_], OptionsPattern[] ] /; 
            Not[ And@@(NonNegative/@{q}) ] || Not @ DuplicateFreeQ[{q}] := (
                Message[CalcPauliTransferMap::error, "The PTM target indices were not unique non-negative integers."];
                $Failed)

        CalcPauliTransferMap[ Subscript[PTM, q__Integer][m_], OptionsPattern[] ] /; 
            Not @ SquareMatrixQ[m] || Length[m] =!= 4^Length@{q} := (
                Message[CalcPauliTransferMap::error, "The PTM matrix was not a compatibly-sized square matrix."];
                $Failed)

        CalcPauliTransferMap[circ_?isCircuitFormat, opts:OptionsPattern[]] := Module[
            {ptm},
            Check[ OptionValue[AssertValidChannels], Return @ $Failed];

            ptm = Check[
                CalcPauliTransferMatrix[circ, FilterRules[{opts}, Options @ CalcPauliTransferMatrix]], 
                Message[CalcPauliTransferMap::error, "Unable to determine PTM as per the above error."];
                Return @ $Failed];
            
            CalcPauliTransferMap[ptm, FilterRules[{opts}, Options @ CalcPauliTransferMap]]
        ]



        (* 
         * Front-end functions for visualising
         * Pauli transfer maps
         *)

        getPTMapGraph[edges_, edgeLabels_, edgeStyles_, vertLabels_,  opts___] :=
            Graph[
                edges,
                opts,
                EdgeLabels -> edgeLabels,
                EdgeStyle -> edgeStyles,
                VertexLabels -> vertLabels,
                VertexStyle -> White
            ]
        
        getIndexToPauliStrFormFunc[form_, targs_, caller_Symbol] := 
            Switch[form,
                "Subscript",
                    GetPauliStringRetargeted[
                        GetPauliString[#, Length[targs]],
                        MapThread[Rule, {Range @ Length @ targs - 1, targs}]] &,
                "Index",
                    Identity,
                "Kronecker",
                    GetPauliStringReformatted[GetPauliString[#,targs,"RemoveIds"->False], "Kronecker"] &,
                "String",
                    GetPauliStringReformatted[GetPauliString[#,targs,"RemoveIds"->False], "String"] &,
                "Hidden",
                    ("" &),
                _,
                    Message[caller::error, "Unrecognised value for option \"PauliStringForm\". See ?" <> ToString@caller]
            ]

        Options[DrawPauliTransferMap] = {
            "PauliStringForm" -> "Subscript", (* or "Index", "Kronecker", "String", "Hidden" *)
            "ShowCoefficients" -> True,
            "EdgeDegreeStyles" -> Automatic (* or a list of styles *),
            AssertValidChannels -> True
        };

        DrawPauliTransferMap[ Subscript[PTMap, q__Integer?NonNegative][rules__], opts:OptionsPattern[{DrawPauliTransferMap,Graph}] ] := Module[
            {edges, edgeLabels, vertInds, vertFormFunc, vertLabels, vertDegrees, maxDegree, degreeStyles, edgeStyles},

            (* fail immediately if given unrecognised option *)
            Check[OptionValue["PauliStringForm"], Return @ $Failed];

            (* warn about not plotting null entries *)
            If[ MemberQ[{rules}, _->{}], Message[DrawPauliTransferMap::error, 
                "Warning: The Pauli transfer map produces no Pauli string from some initial strings. " <>
                "These edges (and null strings) are not being plotted. Hide this warning with Quiet[]."]];

            (* get {pauliInd -> pauliInd, ...} **)
            edges = Flatten @ Table[ rule[[1]]->rhs[[1]], {rule,{rules}}, {rhs,rule[[2]]}];
            
            (* get { (pauliInd -> pauliInd) -> coeff, ...} *)
            edgeLabels = If[
                OptionValue["ShowCoefficients"],
                Flatten @ Table[( rule[[1]]->rhs[[1]] ) -> rhs[[2]] , {rule,{rules}}, {rhs,rule[[2]]}],
                {}];
            
            (* get {pauliInd -> vertFormFunc[pauliInd], ... } *)
            vertInds = DeleteDuplicates @ edges[[All,1]];
            vertFormFunc = Check[
                getIndexToPauliStrFormFunc[OptionValue["PauliStringForm"], {q}, DrawPauliTransferMap], 
                Return @ $Failed];
            vertLabels = Table[ 
                With[{label = vertFormFunc@v},
                    If[label === "", Nothing, v->label]],
                {v, vertInds}];
            
            (* count degree of each edge's FROM node *)
            vertDegrees = Table[
                vert -> Count[edges, vert->_],
                {vert, vertInds}];
            maxDegree = Max @ vertDegrees[[All, 2]];

            (* accept (and pad) user override of per-degree edge colours *)
            degreeStyles = If[
                OptionValue["EdgeDegreeStyles"] === Automatic,
                ColorData["Pastel"] /@ Range[0, 1, If[maxDegree === 1, 1, 1/(maxDegree-1)]],
                PadRight[OptionValue["EdgeDegreeStyles"], maxDegree, OptionValue["EdgeDegreeStyles"]]];

            (* assign a style to each edge according to their FROM node degree *)
            edgeStyles = Table[
                edge -> degreeStyles[[ First[edge] /. vertDegrees ]],
                {edge, edges}];
            
            (* obtain and return the Graph (is rendered immediately) *)
            getPTMapGraph[edges, edgeLabels, edgeStyles, vertLabels, Sequence @@ FilterRules[{opts}, Options[Graph]] ]
        ]

        DrawPauliTransferMap[ ptmOrCirc:(Subscript[PTM,_][_] | _?isCircuitFormat), opts:OptionsPattern[{CalcPauliTransferMap,DrawPauliTransferMap,Graph}] ] :=
            Module[
                {map, calcOpts, drawOpts, errFlag=False},

                (* attempt to auto-generate PTM of circuit, passing along CalcPauliTransferMap[] options *)
                calcOpts = FilterRules[{opts}, Options[CalcPauliTransferMap]];
                map = Enclose[ 
                    ConfirmQuiet @ CalcPauliTransferMap[ptmOrCirc, Sequence @@ calcOpts],
                    ( Message[DrawPauliTransferMap::error, "Failed to automatically obtain the PTMap due to the below error:"]; 
                      ReleaseHold @ # @ "HeldMessageCall";
                      errFlag = True; ) & ];

                (* return immediately if PTM generation failed *)
                If[errFlag, Return @ $Failed];

                (* otherwise recurse, passing along Graph styling options *)
                drawOpts = FilterRules[{opts}, Options[DrawPauliTransferMap] ~Join~ Options[Graph]];
                DrawPauliTransferMap[map, Sequence @@ drawOpts]
            ]

        DrawPauliTransferMap[___] := invalidArgError[DrawPauliTransferMap]



        (* 
         * Front-end functions for effecting
         * Pauli transfer maps upon Pauli strings
         *)


        Options[ApplyPauliTransferMap] = {
            "CacheMaps" -> "UntilCallEnd" (* or "Forever" or "Never" *)
        };

        (* ApplyPauliTransferMap additionally accepts all options to CalcPauliTransferMap which is called internally *)
        applyPTMapOptPatt = OptionsPattern @ {ApplyPauliTransferMap, CalcPauliTransferMap};

        (* signature patterns *)
        ptmapPatt = Subscript[PTMap, __Integer][__Rule];
        ptmatrPatt = Subscript[PTM, __Integer][_?SquareMatrixQ];
        mixedGatesAndMapsPatt = { (_?isGateFormat | ptmatrPatt | ptmapPatt) .. };

        resetCachedPTMaps[] := (

            (* clear all overloads, including the base definition *)
            Clear[obtainCachedPTMap];

            (* restore the base definition, which ... *)
            obtainCachedPTMap[compGate_, opts___] := 

                (* computes maps, and saves them as an overload, specific to the options *)
                obtainCachedPTMap[compGate, opts] =
                     CalcPauliTransferMap[compGate, Sequence @@ FilterRules[{opts},Options@CalcPauliTransferMap] ]
        )

        (* immediately call clear to create initial definition *)
        resetCachedPTMaps[];

        calcAndCachePTMaps[mixed_List, cacheOpt_String, opts___ ] :=
            Table[
                Switch[item,

                    (* keep PTMaps, and convert all PTMs to PTMaps*)
                    ptmapPatt, item,
                    ptmatrPatt, CalcPauliTransferMap[item],

                    (* but for gates and sub-circuits... *)
                    _, If[
                        (* if user requests caching ... *)
                        MatchQ[cacheOpt, "Forever"|"UntilCallEnd"],

                        (* then cache the compacted parameterised gate's PTMap *)
                        Module[{comp,rules, paramed,subs, ptmap},
                            {comp, rules} = GetCircuitCompacted[item]; (* may throw error *)
                            {paramed, subs} = GetCircuitParameterised[comp, TEMPINTERNALPARAM];
                            ptmap = obtainCachedPTMap[paramed, opts] /. subs;
                            First @ GetCircuitRetargeted[ptmap, rules]
                        ],
                        (* else compute the map afresh *)
                        CalcPauliTransferMap[item]]
                ],
                {item, mixed}
            ]

        validatePauliTransferMapOptions[caller_Symbol, applyPTMapOptPatt] := (

            (* validate all options are recognised *)
            Check[ OptionValue@"CacheMaps", Return @ $Failed];

            (* validate cache setting is valid *)
            If[Not @ MemberQ[{"Forever", "UntilCallEnd", "Never"}, OptionValue@"CacheMaps"],
                Message[caller::error, "Option \"CacheMaps\" must be one of \"Forever\", \"UntilCallEnd\" or \"Never\". See ?ApplyPauliTransferMap."]; 
                Return @ $Failed];
        )

        getAndValidateAllGatesAsPTMaps[mixed_List, caller_Symbol, opts:applyPTMapOptPatt] :=
            Module[{cacheOpt=Opt, maps=$Failed},
                cacheOpt = OptionValue["CacheMaps"]; (* gauranteed not to throw; prior validated *)

                (* optionally pre-clear cache *)
                If[ cacheOpt === "Never", resetCachedPTMaps[] ];
                
                (* attempt to precompute all maps ... *)
                Enclose[
                    maps = calcAndCachePTMaps[mixed, cacheOpt, opts] // ConfirmQuiet,

                    (* and abort immediately if any fail, to avoid caching errors *)
                    ( Message[caller::error, "Could not pre-compute the Pauli transfer maps due to the below error:"]; 
                      ReleaseHold @ # @ "HeldMessageCall" ) & ];

                (* optionally clear cache (even if failed), then return maps (which might be $Failed) *)
                If[ cacheOpt === "UntilCallEnd", resetCachedPTMaps[] ];
                maps
            ]


        applyPTMapToPauliState[inDigits:{__Integer}, Subscript[PTMap, q__][rules__]] := 
            Module[{numQb,inInd},

                (* extract base-4 index of targeted inDigits *)
                numQb = Length @ {q};
                inInd = FromDigits[Reverse @ inDigits[[-{q}-1]], 4];

                (* short-circuit if map produces null state (as do fully-mixing channels) *)
                If[(inInd /. {rules}) === {}, Return @ {}];

                MapAt[
                    (* which maps to a list of outInds. For each... *)
                    Function[{outInd},
                    
                        (* replace the targeted inDigits with their mapped values *)
                        ReplacePart[inDigits,
                            MapThread[Rule, {Reverse[-{q}-1], IntegerDigits[outInd,4,numQb]}]]],
                
                    inInd /. {rules}, {All,1}]
            ]

        getPauliStringInitStatesForPTMapSim[pauliStr_, maps_List] := 
            With[
                (* ensure we use sufficiently many digits to represent the initial pauli products *)
                {numQb = Max[ getNumQubitsInPauliString @ pauliStr, 1 + (List @@@ maps[[All, 0]])[[All, 2 ;;]] ]},
                {states = GetPauliStringReformatted[pauliStr, numQb, "Digits"]},

                (* ensure return format is {{pauli, coeff}, ...} even for a single product*)
                If[ MatchQ[pauliStr, pauliOpPatt|pauliProdPatt], {{states,1}}, states]
            ]

        ApplyPauliTransferMap[ pauliStr_?isValidSymbolicPauliString, map:ptmapPatt, opts:OptionsPattern[] ] :=
            Module[
                {out, scalars},

                (* we don't actually use the options (they inform PTMap gen), but we still validate them *)
                Check[ validatePauliTransferMapOptions[ApplyPauliTransferMap, opts], Return @ $Failed];

                (* apply the PTM to each input pauli product ... *)
                out = Plus @@ Flatten[ Table[

                    (* multiplying the input and output coefficients *)
                    inState[[2]] * outState[[2]] * GetPauliString @ outState[[1]], 

                    (* (iterate each input product) *)
                    {inState, getPauliStringInitStatesForPTMapSim[pauliStr, {map}]},

                    (* (iterate each resulting output product) **)
                    {outState, applyPTMapToPauliState[inState[[1]], map]}], 1];

                (* the result may contain a +0 scalar because of unsimplified-to-zero map elems, which we discard... *)
                If[
                    Head @ out === Plus, 
                    scalars = Cases[out, Except[_?isValidSymbolicPauliString]];

                    (* but we check that scalar hasn't grown concerningly large *)
                    If[scalars =!= {} && Not @ PossibleZeroQ @ Chop @ Max @ Abs @ scalars,

                        Message[ApplyPauliTransferMap::error, 
                            "A numerical artefact in ApplyPauliTransferMap[] grew too large (to value " <>
                            ToString @ StandardForm @ First @ scalars <> "), and likely resulted from the " <>
                            "input PTMap being unsimplified or containing an insufficiently precise amplitude."];
                        
                        (* otherwise we error out; this $Failed won't be seen by wrapped calls using Enclose[] *)
                        Return @ $Failed];

                    (* harmless, negligible scalars are removed *)
                    out = DeleteCases[out, Or @@ scalars]];

                (* return a valid Pauli string *)
                out
            ]

        ApplyPauliTransferMap[ pauliStr_?isValidSymbolicPauliString, maps:{ptmapPatt..}, opts:OptionsPattern[] ] :=
            (
                (* we don't use nor pass on the options (they inform PTMap gen), but we still validate them  *)
                Check[ validatePauliTransferMapOptions[ApplyPauliTransferMap, opts], Return @ $Failed];

                (* apply each map in turn to the growing pauli string, and simplify the end result *)
                SimplifyPaulis @ Fold[ApplyPauliTransferMap, pauliStr, maps]
            )

        ApplyPauliTransferMap[ pauliStr_?isValidSymbolicPauliString, mixed:mixedGatesAndMapsPatt, opts:OptionsPattern[] ] := 
            Module[{maps},
                (* validate the options *)
                Check[ validatePauliTransferMapOptions[ApplyPauliTransferMap, opts], Return @ $Failed];

                (* validate and pre-compute all PTMaps, managing all caching *)
                maps = Check[ getAndValidateAllGatesAsPTMaps[mixed, ApplyPauliTransferMap, opts], Return @ $Failed ];

                (* obtain output pauli string; no options need to be propogated *)
                ApplyPauliTransferMap[pauliStr, maps]]

        ApplyPauliTransferMap[ pauliStr_, gate_?isGateFormat, opts___ ] :=
            (* permit passing single gate for user convenience *)
            ApplyPauliTransferMap[ pauliStr, {gate}, opts ]

        ApplyPauliTransferMap[___] := invalidArgError[ApplyPauliTransferMap]



        (* 
         * Front-end functions for obtaining
         * the full tree evluation of PTMaps
         * operating upon a Pauli string.
         *)
                
        getSimplePTMapEvaluationGraph[inStates:{ {{__Integer}, _} ..}, maps_List, mergeStates_:True] := 
            Module[
                {layers={}, currLayer, newLayer, id=1},

                (* add initial states where non-existent ancestor has id 0 *)
                AppendTo[layers, Table[{First@s, id++, {{0,Last@s}}}, {s,inStates}]];
                
                (* apply each map in-turn to the last layer *)
                Do[
                    currLayer = Last @ layers;
                    
                    (* label each returned state by the input state which created it *)
                    newLayer = Table[
                        {state[[1]], id++, {{currLayer[[i,2]], state[[2]]}}},
                        {i, Length @ currLayer},
                        {state, applyPTMapToPauliState[currLayer[[i,1]], map]}
                    ];
                    newLayer = Flatten[newLayer, 1];
                    
                    (* merge colliding Pauli states, arbitrarily picking one id of each group *)
                    If[mergeStates,
                        newLayer = Table[
                            {group[[1,1]], group[[1,2]], Join @@ group[[All,3]]},
                            {group, GatherBy[newLayer, First]}]];
                    
                    (* record the new layer *)
                    AppendTo[layers, newLayer],
                    {map, maps}
                ];
                
                (* return all layers, where layer[[i]] = { 
                * {paulis, id, {{ancestor,coeff}, {ancestor,coeff},...}, ...  } *)
                layers
            ]

        getDetailedPTMapEvaluationGraph[simpleGraph_, include_List:Automatic] := 
            Module[
                {data=<||>, states, isIncluded},

                (* currently 'include' is only supplied by internal functions, so
                 * we don't bother validating compatible combinations *)
                isIncluded = Function[{key}, Or[include === Automatic, MemberQ[include, key]]];

                (* states[[i]] = {paulis, id, {{ancestor id, coeff}, ...}} *)
                states = Flatten[simpleGraph, 1];

                (* {id, id, id, ...} *)
                If[ isIncluded @ "Ids",
                    data["Ids"] = Flatten @ simpleGraph[[All, All, 2]] ];
                
                (* one sublist per layer; { {id,id}, {id,id,id}, ... } *)
                If[ isIncluded @ "Layers",
                    data["Layers"] = simpleGraph[[All, All, 2]]];

                (* scalars *)
                If[ isIncluded @ "NumQubits",
                    data["NumQubits"] = Length @ First @ First @ states];
                If[ isIncluded @ "NumNodes",
                    data["NumNodes"] = Total[Length /@ simpleGraph]];
                If[ isIncluded @ "NumLeaves",
                    data["NumLeaves"] = Length @ Last @ simpleGraph];
                
                (* <| id -> X0 Y1, ... |> *)
                If[ isIncluded @ "States",
                    data["States"] = <|Table[ s[[2]] -> GetPauliString @ s[[1]], {s,states} ]|>];

                (* <| id -> {id,id}, ... |> *)
                If[ isIncluded @ "Parents",
                    data["Parents"] = <|Table[ s[[2]] -> s[[3,All,1]] /. 0->Nothing, {s,states} ]|> ];
                If[ isIncluded @ "Children",
                    data["Children"] = <|Table[ s[[2]] -> Cases[states, c_?(MemberQ[#[[3,All,1]],s[[2]]]&):>c[[2]]], {s,states} ]|> ];

                (* <| id -> <|id->(expr), id->(expr)|> ... |> *)
                If[ isIncluded @ "ParentFactors",
                    data["ParentFactors"] = <|Table[ s[[2]] -> <|Table[Rule@@p, {p,s[[3]]}]|>, {s,states}]|>];

                (* <| id -> 0, id->4, ... |> *)
                If[ isIncluded  @ "Weights",
                    data["Weights"] = <|Table[ s[[2]] -> Count[s[[1]], _?Positive], {s,states} ]|> ];
                If[ isIncluded @ "Indegree",
                    data["Indegree"] = <|Table[ id -> Length @ data["Parents"] @ id, {id, data["Ids"]} ]|> ];
                If[ isIncluded @ "Outdegree",
                    data["Outdegree"] = <|Table[ id -> Length @ data["Children"] @ id, {id, data["Ids"]} ]|> ];
                
                (* <| id -> (symbolic expression), ... |> *)
                If[ isIncluded @ "Coefficients",
                    data["Coefficients"] = <|Table[ state[[2]]->state[[3,1,2]], {state, First@simpleGraph} ]|>;
                    Do[
                        data["Coefficients"][state[[2]]] = Sum[
                            parent[[2]] * data["Coefficients"][parent[[1]]], 
                            {parent, state[[3]]}],
                        {layer, Rest[simpleGraph]},
                        {state, layer}
                    ]
                ];
                
                (* one symbolically weighted sum of Pauli strings per layer *)
                If[ isIncluded @ "Strings",
                    data["Strings"] = Table[
                        (data["Coefficients"]/@ids) . (data["States"]/@ids),
                        {ids, data["Layers"]}]
                ];
                
                (* return *)
                data
            ]

        Options[CalcPauliTransferEval] = {
            "CombineStrings" -> True,
            "OutputForm" -> "Simple" (* or "Detailed" *)
        };

        (*CalcPauliTransferEval additionally accepts all options to ApplyPauliTransferMap (and its subroutines) which are internally called *)
        calcPTEvalOptPatt = OptionsPattern @ {CalcPauliTransferEval, Sequence @@ First @ applyPTMapOptPatt};

        validateCalcPauliTransferEvalOptions[caller_Symbol, opts:calcPTEvalOptPatt] := 
            With[
                {otherOpts = FilterRules[{opts}, Except @ Options @ CalcPauliTransferEval]},

                (* validate the the PTMap eval options *)
                Check[ validatePauliTransferMapOptions[caller, Sequence @@ otherOpts], Return @ $Failed];

                (* validate the the CalcPauliTransferEval specific options *)
                If[ Not @ BooleanQ @ OptionValue @ "CombineStrings",
                    Message[caller::error, "Option \"CombineStrings\" must be True or False. See ?CalcPauliTransferEval."];
                    Return @ $Failed ];

                (* validate the OutputForm option *)
                If[ Not @ MemberQ[{"Simple","Detailed"}, OptionValue @ "OutputForm"],
                    Message[caller::error, "Option \"OutputForm\" must be \"Detailed\" or \"Simple\". See ?CalcPauliTransferEval."];
                    Return @ $Failed ];
            ]

        CalcPauliTransferEval[ pauliStr_?isValidSymbolicPauliString, maps:{ptmapPatt..}, opts:calcPTEvalOptPatt ] := 
            Module[
                {inStates, outEval},

                (* validate options (including those for inner functions like CalcPauliTransferMap) *)
                Check[validateCalcPauliTransferEvalOptions[CalcPauliTransferEval, opts], Return @ $Failed];

                (* compute simple evaluation graph *)
                inStates = getPauliStringInitStatesForPTMapSim[pauliStr, maps];
                outEval = getSimplePTMapEvaluationGraph[inStates, maps, OptionValue @ "CombineStrings"];

                (* optionally post-process graph *)
                If[ OptionValue @ "OutputForm" === "Detailed",
                    outEval = getDetailedPTMapEvaluationGraph[outEval]];

                outEval
            ]

        CalcPauliTransferEval[ pauliStr_?isValidSymbolicPauliString, mixed:mixedGatesAndMapsPatt, opts:calcPTEvalOptPatt ] := 
            Module[{maps,mapGenOpts},

                (* validate CalcPauliTransferEval options, and those needed by subsequent PTMap generation *)
                Check[validateCalcPauliTransferEvalOptions[CalcPauliTransferEval, opts], Return @ $Failed];

                (* validate and pre-compute all PTMaps, managing all caching *)
                mapGenOpts = FilterRules[{opts}, Except @ Options @ CalcPauliTransferEval];
                maps = Check[ getAndValidateAllGatesAsPTMaps[mixed, CalcPauliTransferEval, mapGenOpts], Return @ $Failed ];

                CalcPauliTransferEval[pauliStr, maps, opts]
            ]

        CalcPauliTransferEval[ pauliStr_?isValidSymbolicPauliString, gate_?isGateFormat, opts:calcPTEvalOptPatt ] :=
            CalcPauliTransferEval[pauliStr, {gate}, opts]

        CalcPauliTransferEval[___] := invalidArgError[CalcPauliTransferEval]



        (* 
         * Front-end functions for rendering
         * a Pauli transfer evalaution tree
         *)

        Options[DrawPauliTransferEval] = {
            "PauliStringForm" -> Automatic, (* or "Subscript", "Index", "Kronecker", "String", "Hidden" *)
            "ShowCoefficients" -> Automatic, (* or True, False *)
            "EdgeDegreeStyles" -> Automatic, (* or a list of styles *)
            "HighlightPathTo" -> {} (* or a weighted sum of Pauli strings, or a list thereof *)
        };

        (* DrawPauliTransferEval additionally accepts all options to CalcPauliTransferEval and Graph *)
        drawPTEvalOptPatt = OptionsPattern @ {DrawPauliTransferEval, Sequence @@ First @ calcPTEvalOptPatt, Graph};

        drawPTMapEvaluationGraph[eLabels_, vLabels_, eStyles_, eHighlights_, opts___] := 
            Graph[
                eLabels,
                opts,
                EdgeStyle -> eStyles,
                VertexStyle -> White,
                VertexLabels -> vLabels,
                GraphHighlight -> eHighlights,
                GraphLayout -> "LayeredDigraphEmbedding"
            ]

        getVertexLabelsForPTEval[subscriptStates_, numQubits_Integer, formOpt_String] :=
            Switch[formOpt,
                "Hidden", {},
                "Subscript", subscriptStates,
                _, MapAt[GetPauliStringReformatted[#,numQubits,formOpt]&, subscriptStates, {All,2}]]

        getAllAncestorEdgesOfNode[parents_Association][id_] := 
            Flatten @ Table[
                {parentId -> id, getAllAncestorEdgesOfNode[parents][parentId]},
                {parentId, parents[id]}
            ]

        extractCalcPTEvalOptions[ opts___ ] :=
            Sequence @@ FilterRules[{opts}, Options /@ First @ calcPTEvalOptPatt // Flatten]

        validateDrawPauliTransferEvalOptions[ opts:drawPTEvalOptPatt ] := (

            (* check all options are recognised between all functions in drawPTEvalOptPatt *)
            Check[ OptionValue @ "PauliStringForm", Return @ $Failed ];

            (* check the options passed on to CalcPauliTransfer eval have valid values *)
            Check[
                validateCalcPauliTransferEvalOptions[DrawPauliTransferEval, extractCalcPTEvalOptions @ opts],
                Return @ $Failed];

            (* check all the options specific to DrawPauliTransferEval are valid *)
            If[ Not @ MemberQ[{Automatic,True,False}, OptionValue @ "ShowCoefficients"],
                Message[DrawPauliTransferEval::error, "Option \"ShowCoefficients\" must be Automatic, True or False. See ?DrawPauliTransferEval."];
                Return @ $Failed];

            If[ Not @ MemberQ[{Automatic,"Hidden","Subscript","Index","Kronecker","String"}, OptionValue @ "PauliStringForm"],
                Message[DrawPauliTransferEval::error, "Invalid value for option \"PauliStringForm\". See ?DrawPauliTransferEval."];
                Return @ $Failed];

            If[ Not @ MatchQ[OptionValue @ "HighlightPathTo", (_?isValidSymbolicPauliString|{___?isValidSymbolicPauliString})],
                Message[DrawPauliTransferEval::error, "Invalid value for option \"HighlightPathTo\". See ?DrawPauliTransferEval."];
                Return @ $Failed];
        )

        (* match only Associations with the needed keys and item structures *)
        detailedPTMapEvalPatt = KeyValuePattern[{
            "Children" -> Association[(_Integer -> {___Integer}) .. ],
            "Outdegree" -> Association[(_Integer -> _Integer) .. ],
            "NumQubits" -> _Integer

            (* additional keys are needed depending on option values; for now we trust they're supplied *)
        }];

        DrawPauliTransferEval[ eval:detailedPTMapEvalPatt, opts:drawPTEvalOptPatt ] := 
            Module[
                {edges,edgesAndLabels, vertexLabels, maxDegree,degreeStyles,edgeStyles, showCoeffs,stateForm, hlStrs,hlLeafIds,hlEdges},

                (* validate options *)
                Check[validateDrawPauliTransferEvalOptions[opts], Return @ $Failed];

                (* warn if eval history contains null states (e.g. by fully-mixing channels) *)
                If[
                    (* which is detectable by non-leaf nodes having no children *)
                    AnyTrue[
                        Keys @ Select[eval @ "Outdegree", PossibleZeroQ],
                        (Not @ MemberQ[Last @ eval @ "Layers", #]&)
                    ],
                    Message[DrawPauliTransferEval::error,
                    "Warning: the evaluation includes Pauli strings being mapped to null strings, " <>
                    "as can occur from fully-mixing channels. The null strings and edges to them are " <>
                    "not being rendered. Suppress this warning using Quiet[]."]];

                (* { id->id ... } *)
                edges = Thread /@ Normal @ eval["Children"] // Flatten;

                (* automatically decide whether to show coefficients or state labels.
                 * This design is flawed; the most common case (user leaves settings 
                 * on Automatic) will still mean 'eval' contains pre-computed "States"
                 * and "ParentFactors" even when they won't be shown due to the below
                 * auto-disable. We should avoid the pointless pre-computation, especially
                 * because this is likely an expensive scenario when auto-hid! *)
                showCoeffs = OptionValue @ "ShowCoefficients";
                stateForm  = OptionValue @ "PauliStringForm";
                If[showCoeffs === Automatic, showCoeffs = Length[edges] < 50];
                If[stateForm === Automatic, stateForm = If[
                    eval["NumLeaves"] * eval["NumQubits"] < 50, "String", "Hidden"]];

                (* optionally { Labeled[id->id, fac] ... } *)
                edgesAndLabels = If[ Not @ showCoeffs, edges, Table[
                    Labeled[r, eval["ParentFactors"][Last@r][First@r] ],
                    {r,edges}]];

                (* { id->X0Y1 or -> XYZ, or etc ... }. Note that "States" might not be present in eval; that's okay! *)
                vertexLabels = getVertexLabelsForPTEval[Normal @ eval @ "States", eval @ "NumQubits", stateForm];

                (* accept (and pad) user override of per-degree edge colours *)
                maxDegree = Max @ Values @ eval["Outdegree"];
                degreeStyles = If[
                    OptionValue @ "EdgeDegreeStyles" === Automatic,
                    ColorData["Pastel"] /@ Range[0, 1, If[maxDegree === 1, 1, 1/(maxDegree-1)]],
                    PadRight[OptionValue @ "EdgeDegreeStyles", maxDegree, OptionValue @ "EdgeDegreeStyles"]];

                (* { (id->id) -> style, ... }*)
                edgeStyles = Table[
                    (edge) -> degreeStyles[[ eval["Outdegree"] @ First @ edge ]],
                    {edge, Thread /@ Normal @ eval @ "Children" // Flatten}];

                (* ensure user-chosen states to highlight is a list (even of one string) *)
                hlStrs = OptionValue @ "HighlightPathTo";
                If[Head @ hlStrs =!= List, hlStrs = {hlStrs}];

                (* collect all leaf-nodes with a non-zero overlap with the user string(s) *)
                hlLeafIds = DeleteDuplicates @ Flatten @ Table[ 
                    If[ Not @ PossibleZeroQ @ GetPauliStringOverlap[str, eval["States"] @ leafId],
                        leafId, Nothing],
                    {str, hlStrs},
                    {leafId, Last @ eval @ "Layers"}];
    
                hlEdges = getAllAncestorEdgesOfNode[eval@"Parents"] /@ hlLeafIds // Flatten // DeleteDuplicates;
                
                drawPTMapEvaluationGraph[
                    edgesAndLabels, vertexLabels, edgeStyles, hlEdges,
                    Sequence @@ FilterRules[{opts}, Options[Graph]]]
            ]

        simplePTMapEvalPatt = { { { {__Integer}, _Integer, {{_Integer,_}...} } ... } .. };

        DrawPauliTransferEval[ layers:simplePTMapEvalPatt, opts:drawPTEvalOptPatt ] := 
            Module[
                {keys, assoc},

                (* validate options *)
                Check[validateDrawPauliTransferEvalOptions[opts], Return @ $Failed];

                (* compute a simplified 'Detailed' Association containing only the necessary keys *)
                keys = {"Ids", "NumQubits", "Children", "Outdegree"};

                (* needed to discover null Pauli strings to issue warning *)
                AppendTo[keys, "Layers"]; 

                If[ OptionValue @ "ShowCoefficients" =!= False,
                    keys = Join[keys, {"ParentFactors"}]];

                If[ OptionValue @ "PauliStringForm" =!= "Hidden",
                    keys = Join[keys, {"States", "NumLeaves"}]];

                If[ OptionValue @ "HighlightPathTo" =!= {},
                    keys = Join[keys, {"States", "Parents", "Layers"}]]; (* duplication of "States" is ok *)

                assoc = getDetailedPTMapEvaluationGraph[layers, keys];
                DrawPauliTransferEval[assoc, opts]
            ]

        DrawPauliTransferEval[ pauliStr_?isValidSymbolicPauliString, circ:(mixedGatesAndMapsPatt|_?isGateFormat), opts:drawPTEvalOptPatt ] := (
            Check[validateDrawPauliTransferEvalOptions[opts], Return @ $Failed];
            DrawPauliTransferEval[CalcPauliTransferEval[pauliStr, circ, extractCalcPTEvalOptions @ opts], opts] )

        DrawPauliTransferEval[___] := invalidArgError[DrawPauliTransferEval];


    End[ ]
                                       
EndPackage[]

Needs["QuEST`Option`"]

Needs["QuEST`Gate`"]

Needs["QuEST`DeviceSpec`"]

Needs["QuEST`Deprecated`"]
