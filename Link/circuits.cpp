/** @file
 * Contains functions for applying circuits to registers.
 *
 * @author Tyson Jones
 */
 
#include <math.h>

#include "wstp.h"
#include "QuEST.h"
#include "QuEST_internal.h"

#include "circuits.hpp"
#include "errors.hpp"
#include "decoders.hpp"
#include "extensions.hpp"
#include "link.hpp"
#include "derivatives.hpp"
#include "utilities.hpp"



/*
 * PI constant needed for (multiControlled) sGate and tGate
 */
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/*
 * Codes for dynamically updating kernel variables, to indicate progress 
 */
#define CALC_PROGRESS_VAR "QuEST`Private`calcProgressVar"



int* local_prepareCtrlCache(int* ctrls, int numCtrls, int addTarg) {
    
    static int ctrlCache[MAX_NUM_TARGS_CTRLS]; 
    for (int i=0; i < numCtrls; i++)
        ctrlCache[i] = ctrls[i];
    if (addTarg != -1)
        ctrlCache[numCtrls] = addTarg;
    return ctrlCache;
}



/* updates the CALC_PROGRESS_VAR in the front-end with the new passed value 
 * which must lie in [0, 1]. This can be used to indicate progress of a long 
 * evaluation to the user 
 */
void local_updateCircuitProgress(qreal progress) {

    // send new packet to MMA
    WSPutFunction(stdlink, "EvaluatePacket", 1);

    // echo the message
    WSPutFunction(stdlink, "Set", 2);
    WSPutSymbol(stdlink, CALC_PROGRESS_VAR);
    WSPutReal64(stdlink, progress);

    WSEndPacket(stdlink);
    WSNextPacket(stdlink);
    WSNewPacket(stdlink);
    
    // a new packet is now expected; caller MUST send something else
}



/*
 * Gate methods
 */

void Gate::init(
    int opcode, 
    int* ctrls,     int numCtrls, 
    int* targs,     int numTargs, 
    qreal* params,  int numParams)
{
    this->opcode = opcode;
    this->ctrls = ctrls;     this->numCtrls = numCtrls;
    this->targs = targs;     this->numTargs = numTargs;
    this->params = params;   this->numParams = numParams;
}

int Gate::getNumOutputs() {
    
    if (opcode == OPCODE_P)
        return 1;
        
    if (opcode == OPCODE_M)
        return numTargs;
        
    return 0;
}

std::string Gate::getOpcodeStr() {

    if (opcode < NUM_OPCODES)
        return opcodeStrings[opcode];
        
    return "opcode: " + std::to_string(opcode);
}

std::string Gate::getName() {
    
    // base name 
    std::string baseLabel = "";
    if (opcode < NUM_OPCODES)
        baseLabel = opcodeNames[opcode];
    else
        baseLabel = "unrecognised-operator";

    // multi-target, multi-qubit, many-target, many-qubit
    std::string targLabel = "";
    switch (opcode) {
        
        // requiredly two-qubit
        case OPCODE_SWAP :
            if (numTargs == 0)
                targLabel = "zero-target ";
            if (numTargs == 1)
                targLabel = "single-target ";
            if (numTargs > 2)
                targLabel = "many-qubit ";
            break;
        
        // provisionally one-qubit
        case OPCODE_R :
            if (numTargs == 0)
                targLabel = "zero-target ";
            if (numTargs == 2)
                targLabel = "two-qubit ";
            if (numTargs > 2)
                targLabel = "many-qubit ";
            break;
            
        // requiredly zero-qubit
        case OPCODE_Fac : 
        case OPCODE_G :
            if (numTargs > 0)
                targLabel = "targeted ";
            break;
        
        // provisionally (and some, requiredly) one-qubit
        case OPCODE_Id :
        case OPCODE_H :
        case OPCODE_X :
        case OPCODE_Y :
        case OPCODE_Z :
        case OPCODE_Rx :
        case OPCODE_Ry :
        case OPCODE_Rz :
        case OPCODE_S :
        case OPCODE_T :
        case OPCODE_Ph :
            if (numTargs == 0)
                targLabel = "zero-target ";
            if (numTargs > 1)
                targLabel = "multi-qubit ";
            break;

        // number of qubits unimportant
        case OPCODE_M :
        case OPCODE_P :
            break;
            
        // explicit number of qubits
        case OPCODE_U :
        case OPCODE_UNonNorm :
        case OPCODE_Matr : 
        case OPCODE_Deph :
        case OPCODE_Depol :
        case OPCODE_Damp :
        case OPCODE_Kraus :
        case OPCODE_KrausNonTP :
            if (numTargs == 0)
                targLabel = "zero-target ";
            if (numTargs == 1)
                targLabel = "single-qubit ";
            if (numTargs == 2)
                targLabel = "two-qubit ";
            if (numTargs > 2)
                targLabel = "many-qubit ";
            break;
            
        // default handled above
    }
    
    // controlled and multi-controlled
    std::string ctrlLabel = "";
    if (numCtrls == 1)
        ctrlLabel = "controlled ";
    if (numCtrls == 2)
        ctrlLabel = "multi-controlled ";
    if (numCtrls > 2)
        ctrlLabel = "many-controlled ";
        
    return ctrlLabel + targLabel + baseLabel;
}

std::string Gate::getSyntax() {
    
    // get gate symbol
    std::string opStr = (opcode < NUM_OPCODES)? getOpcodeStr() : "Unknown";
    std::string form = opStr;
    
    // format target qubits
    if (numTargs != 0) {
        
        switch (opcode) {
            
            // and for this annoying special case, params too
            case OPCODE_R :
                if (numParams < 1 || numTargs != numParams-1)
                    form = opStr + "[uninterpretable]";
                else {
                    form = opStr + "[" + std::to_string(params[0]) + ", ";
                    for (int t=0; t<numTargs; t++) {
                        std::string paulis[] = {"Id", "X", "Y", "Z"};
                        std::string pauliStr = paulis[(int) params[t+1]];
                        form += "Subscript[" + pauliStr + ", " + std::to_string(targs[t]) + "]";
                    }
                    form += "]";
                }
                break;
                
            default:
                form = "Subscript[" + opStr + ", " + local_getCommaSep(targs, numTargs) + "]";
                break;
        }
    }
        
    // format parameters
    if (numParams != 0) {
        
        switch(opcode) {
            
            // skip (handled above)
            case OPCODE_R : 
                break;
            
            // complex matrix
            case OPCODE_U :
            case OPCODE_UNonNorm :
            case OPCODE_Matr : { ;
                int dim = (1<<numTargs);
                if (numParams < 2*2*2 || numParams != 2*dim*dim)
                    form += "[uninterpretable]";
                else {
                    qmatrix matr = local_getQmatrixFromFlatList(params, dim);
                    form += "[ MatrixForm @ " + local_qmatrixToStr(matr) + " ]";
                }
            }
                break;
                
            // complex matrices
            case OPCODE_Kraus :
            case OPCODE_KrausNonTP : { ;
                int numOps = (int) params[0];
                int dim = (1<<numTargs);
                if (numOps < 1 || numParams != 1 + 2*dim*dim*numOps)
                    form += "[uninterpretable]";
                else {        
                    form += "[ MatrixForm /@ { ";
                    for (int n=0; n < numOps; n++) {
                        qmatrix op = local_getQmatrixFromFlatList(&params[1 + 2*dim*dim*n], dim);
                        form += local_qmatrixToStr(op) + ((n<numOps-1)? ", " : "}]");
                    }
                }
            }
                break;
                
            // complex scalar
            case OPCODE_Fac :
                if (numParams%2)
                    form += "[uninterpretable]";
                else {
                    form += "[";
                    for (int i=0; i<numParams; i+=2)
                        form += local_qcompToStr( qcomp(params[i],params[i+1]) ) + ((i<numParams-2)? "," : "]");
                }
                break;
            
            // real or integer scalars
            default: { ;
                form += "[" + local_getCommaSep(params, numParams) + "]";
            }
                break;
        }
    }
    
    // format control qubits
    if (numCtrls > 0)
        form = "Subscript[C," + local_getCommaSep(ctrls, numCtrls) + "][" + form + "]";
        
    // convert to Mathematica front-end graphics markup
    return local_getStandardFormFromMMA(form);
}

void Gate::validate() {
    
    /* This function only validates the meta-gate conventions like number of 
     * targets and parameters. It does not validate whether a qubit is in bounds,
     * or whether the parameter values are normalised, or other run-time validations 
     * performed by the QuEST backend. 
     */
    
    switch(opcode) {
        
        case OPCODE_G :
            if (numParams != 1)
                throw local_wrongNumGateParamsExcep(getOpcodeStr(), numParams, 1); // throws
            if (numCtrls != 0)
                throw local_gateUnsupportedExcep("controlled " + getOpcodeStr()); // throws
            if (numTargs != 0)
                throw local_wrongNumGateTargsExcep(getOpcodeStr(), numTargs, "0 targets"); // throws
            return;
            
        case OPCODE_Fac :
            if (numParams != 2)
                throw local_wrongNumGateParamsExcep(getOpcodeStr(), numParams, 2); // throws
            if (numCtrls != 0)
                throw local_gateUnsupportedExcep("controlled " + getOpcodeStr()); // throws
            if (numTargs != 0)
                throw local_wrongNumGateTargsExcep(getOpcodeStr(), numTargs, "0 targets"); // throws
            return;
            
        case OPCODE_Id :
        case OPCODE_X : 
            if (numParams != 0)
                throw local_wrongNumGateParamsExcep(getOpcodeStr(), numParams, 0); // throws
            return;
                
        case OPCODE_H :
            if (numParams != 0)
                throw local_wrongNumGateParamsExcep(getOpcodeStr(), numParams, 0); // throws
            if (numCtrls != 0)
                throw local_gateUnsupportedExcep("controlled " + getOpcodeStr()); // throws
            if (numTargs != 1)
                throw local_wrongNumGateTargsExcep(getOpcodeStr(), numTargs, "1 target"); // throws
            return;
            
        case OPCODE_S :
        case OPCODE_T :
            if (numParams != 0)
                throw local_wrongNumGateParamsExcep(getOpcodeStr(), numParams, 0); // throws
            if (numTargs != 1)
                throw local_wrongNumGateTargsExcep(getOpcodeStr(), numTargs, "1 target"); // throws
            return;
                    
        case OPCODE_Ph :
            if (numParams != 1)
                throw local_wrongNumGateParamsExcep(getOpcodeStr(), numParams, 1); // throws
            if (numCtrls + numTargs < 1)
                throw local_wrongNumGateTargsExcep(getOpcodeStr(), numCtrls + numTargs, "at least 1 qubit (between control and target qubits)"); // throws
            return;

        case OPCODE_Y :
            if (numParams != 0)
                throw local_wrongNumGateParamsExcep(getOpcodeStr(), numParams, 0); // throws
            if (numTargs != 1)
                throw local_wrongNumGateTargsExcep(getOpcodeStr(), numTargs, "1 target"); // throws
            if (numCtrls > 1)
                throw local_gateUnsupportedExcep("multi-controlled " + getOpcodeStr()); // throws
            return;
            
        case OPCODE_Z :
            if (numParams != 0)
                throw local_wrongNumGateParamsExcep("Z", numParams, 0); // throws
            if (numTargs != 1)
                throw local_wrongNumGateTargsExcep("Z", numTargs, "1 target"); // throws
            return;
    
        case OPCODE_Rx :
        case OPCODE_Rz :
        case OPCODE_Ry :
            if (numParams != 1)
                throw local_wrongNumGateParamsExcep(getOpcodeStr(), numParams, 1); // throws
            return;
            
        case OPCODE_R:
            if (numTargs != numParams-1)
                throw QuESTException("", 
                    std::string("An internel error in " + getOpcodeStr() + " occured! ") +
                    "The quest_link process received an unequal number of Pauli codes " + 
                    "(" + std::to_string(numParams-1) + ") and target qubits " + 
                    "(" + std::to_string(numTargs) + ")!"); // throws
            return;
        
        case OPCODE_U :
        case OPCODE_UNonNorm : 
        case OPCODE_Matr : { ;
            long long int dim = (1LL << numTargs);
            if (numParams != 2 * dim*dim)
                throw QuESTException("", std::to_string(numTargs) + "-qubit " + getOpcodeStr() + 
                   " accepts only " + std::to_string(dim) + "x" +  std::to_string(dim) + " matrices."); // throws
        }
            return;

        case OPCODE_Deph :
        case OPCODE_Depol :
            if (numParams != 1)
                throw local_wrongNumGateParamsExcep(getOpcodeStr(), numParams, 1); // throws
            if (numCtrls != 0)
                throw local_gateUnsupportedExcep("controlled " + getOpcodeStr()); // throws
            if (numTargs != 1 && numTargs != 2)
                throw local_wrongNumGateTargsExcep(getOpcodeStr(), numTargs, "1 or 2 targets"); // throws
            return;
            
        case OPCODE_Damp :
            if (numParams != 1)
                throw local_wrongNumGateParamsExcep(getOpcodeStr(), numParams, 1); // throws
            if (numCtrls != 0)
                throw local_gateUnsupportedExcep("controlled " + getOpcodeStr()); // throws
            if (numTargs != 1)
                throw local_wrongNumGateTargsExcep(getOpcodeStr(), numTargs, "1 target"); // throws
            return;
            
        case OPCODE_SWAP :
            if (numParams != 0)
                throw local_wrongNumGateParamsExcep(getOpcodeStr(), numParams, 0); // throws
            if (numTargs != 2)
                throw local_wrongNumGateTargsExcep(getOpcodeStr(), numTargs, "2 targets"); // throws
            return;
            
        case OPCODE_M :
            if (numParams != 0)
                throw local_wrongNumGateParamsExcep(getOpcodeStr(), numParams, 0); // throws
            if (numCtrls != 0)
                throw local_gateUnsupportedExcep("controlled " + getOpcodeStr()); // throws
            return;
        
        case OPCODE_P:
            if (numParams != 1 && numParams != numTargs)
                throw QuESTException("", 
                    std::string(getOpcodeStr() + " gate specified a different number of binary outcomes ") + 
                    "(" + std::to_string(numParams) + ") than target qubits  " +
                    "(" + std::to_string(numTargs) + ")!"); // throws
            if (numCtrls != 0)
                throw local_gateUnsupportedExcep("controlled " + getOpcodeStr()); // throws
            if (numParams == 1 && params[0] >= (1LL << numTargs))
                throw QuESTException("",
                    "The argument (" + std::to_string((int) params[0]) + 
                    ") to gate " + getOpcodeStr() + " exceeded the maximum binary "
                    "value (" + std::to_string(1LL << numTargs) + ") of the " +
                    std::to_string(numTargs) + " targeted qubits."); // throws
            return;
            
        case OPCODE_Kraus :
        case OPCODE_KrausNonTP : { ;
            int numKrausOps = (int) params[0];
            if (numCtrls != 0)
                throw local_gateUnsupportedExcep("controlled " + getOpcodeStr()); // throws
            if (numTargs != 1 && numTargs != 2)
                throw local_wrongNumGateTargsExcep(getOpcodeStr(), numTargs, "1 or 2 targets"); // throws
            if ((numKrausOps < 1) ||
                (numTargs == 1 && numKrausOps > 4 ) ||
                (numTargs == 2 && numKrausOps > 16))
                throw QuESTException("", 
                    std::to_string(numKrausOps) + " operators were passed to " +
                    std::to_string(numTargs) +  "-qubit Kraus[ops], which accepts only >0 and <=" + 
                    std::to_string((numTargs==1)? 4:16) + " operators!"); // throws
            if (numTargs == 1 && (numParams-1) != 2*2*2*numKrausOps)
                throw QuESTException("", "one-qubit Kraus expects 2-by-2 matrices!"); // throws
            if (numTargs == 2 && (numParams-1) != 4*4*2*numKrausOps)
                throw QuESTException("", "two-qubit Kraus expects 4-by-4 matrices!"); // throws
        }
            return;
            
        default:            
            throw QuESTException("", "circuit contained an unknown gate (" + getOpcodeStr() + ")."); // throws
    }
}

void Gate::applyTo(Qureg qureg, qreal* outputs) {
    
    validate(); // throws
    
    switch(opcode) {
        
        case OPCODE_Id :
            break;
        
        case OPCODE_H :
            hadamard(qureg, targs[0]); // throws
            break;
            
        case OPCODE_S :
            if (numCtrls == 0)
                sGate(qureg, targs[0]); // throws
            else {
                int* ctrlCache = local_prepareCtrlCache(ctrls, numCtrls, targs[0]);
                multiControlledPhaseShift(qureg, ctrlCache, numCtrls+1, M_PI/2); // throws
            }
            break;
            
        case OPCODE_T :
            if (numCtrls == 0)
                tGate(qureg, targs[0]); // throws
            else {
                int* ctrlCache = local_prepareCtrlCache(ctrls, numCtrls, targs[0]);
                multiControlledPhaseShift(qureg, ctrlCache, numCtrls+1, M_PI/4); // throws
            }
            break;
    
        case OPCODE_X :
            if (numCtrls == 0 && numTargs == 1)
                pauliX(qureg, targs[0]); // throws
            else if (numCtrls == 1 && numTargs == 1)
                controlledNot(qureg, ctrls[0], targs[0]); // throws
            else if (numCtrls == 0 && numTargs > 1)
                multiQubitNot(qureg, targs, numTargs); // throws
            else
                multiControlledMultiQubitNot(qureg, ctrls, numCtrls, targs, numTargs); // throws
            break;
            
        case OPCODE_Y :
            if (numCtrls == 0)
                pauliY(qureg, targs[0]); // throws
            else if (numCtrls == 1)
                controlledPauliY(qureg, ctrls[0], targs[0]); // throws
            break;
            
        case OPCODE_Z :
            if (numCtrls == 0)
                pauliZ(qureg, targs[0]); // throws
            else {
                int* ctrlCache = local_prepareCtrlCache(ctrls, numCtrls, targs[0]);
                multiControlledPhaseFlip(qureg, ctrlCache, numCtrls+1); // throws
            }
            break;
    
        case OPCODE_Rx :
            if (numCtrls == 0 && numTargs == 1)
                rotateX(qureg, targs[0], params[0]); // throws
            else if (numCtrls == 1 && numTargs == 1)
                controlledRotateX(qureg, ctrls[0], targs[0], params[0]); // throws
            else {
                enum pauliOpType paulis[MAX_NUM_TARGS_CTRLS]; 
                for (int i=0; i<numTargs; i++)
                    paulis[i] = PAULI_X;
                if (numCtrls == 0)
                    multiRotatePauli(qureg, targs, paulis, numTargs, params[0]); // throws
                else
                    multiControlledMultiRotatePauli(qureg, ctrls, numCtrls, targs, paulis, numTargs, params[0]); // throws
            }
            break;

        case OPCODE_Ry :
            if (numCtrls == 0 && numTargs == 1)
                rotateY(qureg, targs[0], params[0]); // throws
            else if (numCtrls == 1 && numTargs == 1)
                controlledRotateY(qureg, ctrls[0], targs[0], params[0]); // throws
            else {
                enum pauliOpType paulis[MAX_NUM_TARGS_CTRLS]; 
                for (int i=0; i<numTargs; i++)
                    paulis[i] = PAULI_Y;
                if (numCtrls == 0)
                    multiRotatePauli(qureg, targs, paulis, numTargs, params[0]); // throws
                else
                    multiControlledMultiRotatePauli(qureg, ctrls, numCtrls, targs, paulis, numTargs, params[0]); // throws
            }
            break;
            
        case OPCODE_Rz :
            if (numCtrls == 0 && numTargs == 1)
                rotateZ(qureg, targs[0], params[0]); // throws
            else if (numCtrls == 1 && numTargs == 1)
                controlledRotateZ(qureg, ctrls[0], targs[0], params[0]); // throws
            else if (numCtrls == 0 && numTargs > 1)
                multiRotateZ(qureg, targs, numTargs, params[0]); // throws
            else
                multiControlledMultiRotateZ(qureg, ctrls, numCtrls, targs, numTargs, params[0]); // throws
            break;
            
        case OPCODE_R: { ;
            enum pauliOpType paulis[MAX_NUM_TARGS_CTRLS]; 
            for (int p=0; p < numTargs; p++)
                paulis[p] = (pauliOpType) ((int) params[1+p]);
            if (numCtrls == 0)
                multiRotatePauli(qureg, targs, paulis, numTargs, params[0]); // throws
            else
                multiControlledMultiRotatePauli(qureg, ctrls, numCtrls, targs, paulis, numTargs, params[0]); // throws
        }
            break;
        
        case OPCODE_U :
            if (numTargs == 1) {
                ComplexMatrix2 u = local_getMatrix2FromFlatList(params);
                if (numCtrls == 0)
                    unitary(qureg, targs[0], u); // throws
                else
                    multiControlledUnitary(qureg, ctrls, numCtrls, targs[0], u); // throws
            }
            else if (numTargs == 2) {
                ComplexMatrix4 u = local_getMatrix4FromFlatList(params);
                if (numCtrls == 0)
                    twoQubitUnitary(qureg, targs[0], targs[1], u); // throws
                else
                    multiControlledTwoQubitUnitary(qureg, ctrls, numCtrls, targs[0], targs[1], u); // throws
            } 
            else {
                // this is wastefully(?) allocating and deallocating memory on the fly!
                ComplexMatrixN u = createComplexMatrixN(numTargs);
                local_setMatrixNFromFlatList(params, u, numTargs);
                if (numCtrls == 0)
                    multiQubitUnitary(qureg, targs, numTargs, u); // throws
                else
                    multiControlledMultiQubitUnitary(qureg, ctrls, numCtrls, targs, numTargs, u); // throws
                // memory leak if above throws :^)
                destroyComplexMatrixN(u);
            }
            break;
            
        case OPCODE_UNonNorm : { ;
            ComplexMatrixN m = createComplexMatrixN(numTargs);
            local_setMatrixNFromFlatList(params, m, numTargs);
            if (numCtrls == 0)
                applyGateMatrixN(qureg, targs, numTargs, m); // throws
            else
                applyMultiControlledGateMatrixN(qureg, ctrls, numCtrls, targs, numTargs, m); // throws
            // memory leak if above throws :^)
            destroyComplexMatrixN(m);
        }
            break;
            
        case OPCODE_Matr : { ;
            ComplexMatrixN m = createComplexMatrixN(numTargs);
            local_setMatrixNFromFlatList(params, m, numTargs);
            if (numCtrls == 0)
                applyMatrixN(qureg, targs, numTargs, m); // throws
            else
                applyMultiControlledMatrixN(qureg, ctrls, numCtrls, targs, numTargs, m); // throws
            // memory leak if above throws :^)
            destroyComplexMatrixN(m);
        }
            break;
            
        case OPCODE_Deph :
            if (params[0] == 0)
                break; // permit zero-prob decoherence to act on state-vectors
            if (numTargs == 1)
                mixDephasing(qureg, targs[0], params[0]); // throws
            if (numTargs == 2)
                mixTwoQubitDephasing(qureg, targs[0], targs[1], params[0]); // throws
            break;
            
        case OPCODE_Depol :
            if (params[0] == 0)
                break; // permit zero-prob decoherence to act on state-vectors
            if (numTargs == 1)
                mixDepolarising(qureg, targs[0], params[0]); // throws
            if (numTargs == 2)
                mixTwoQubitDepolarising(qureg, targs[0], targs[1], params[0]); // throws
            break;
            
        case OPCODE_Damp :
            if (params[0] == 0)
                break; // permit zero-prob decoherence to act on state-vectors
            mixDamping(qureg, targs[0], params[0]); // throws
            break;
            
        case OPCODE_SWAP:
            if (numCtrls == 0)
                swapGate(qureg, targs[0], targs[1]); // throws
            else {    
                // core-QuEST doesn't yet support multiControlledSwapGate, 
                // so we construct SWAP from 3 CNOT's, and add additional controls
                ComplexMatrix2 u;
                u.real[0][0] = 0; u.real[0][1] = 1; // verbose for old MSVC 
                u.real[1][0] = 1; u.real[1][1] = 0;
                u.imag[0][0] = 0; u.imag[0][1] = 0;
                u.imag[1][0] = 0; u.imag[1][1] = 0;
                int* ctrlCache = local_prepareCtrlCache(ctrls, numCtrls, targs[0]);
                multiControlledUnitary(qureg, ctrlCache, numCtrls+1, targs[1], u); // throws
                ctrlCache[numCtrls] = targs[1];
                multiControlledUnitary(qureg, ctrlCache, numCtrls+1, targs[0], u);
                ctrlCache[numCtrls] = targs[0];
                multiControlledUnitary(qureg, ctrlCache, numCtrls+1, targs[1], u);
            }
            break;
            
        case OPCODE_M:
            for (int q=0; q < numTargs; q++) {
                int outcome = measure(qureg, targs[q]);
                if (outputs != NULL)
                    outputs[q] = (qreal) outcome;
            }
            break;
        
        case OPCODE_P:
            if (numParams > 1) {
                qreal prob = 1;
                for (int q=0; q < numParams; q++)
                    prob *= collapseToOutcome(qureg, targs[q], (int) params[q]); // throws
                if (outputs != NULL)
                    outputs[0] = prob;
            }
            else {
                // work out each bit outcome and apply; right most (least significant) bit acts on right-most target
                qreal prob = 1;
                for (int q=0; q < numTargs; q++)
                    prob *= collapseToOutcome(qureg, targs[numTargs-q-1], (((int) params[0]) >> q) & 1); // throws
                 if (outputs != NULL)
                    outputs[0] = prob; 
            }
            break;
            
        case OPCODE_Kraus: { ;
            int numKrausOps = (int) params[0];
            if (numTargs == 1) {
                ComplexMatrix2 krausOps[4];
                for (int n=0; n < numKrausOps; n++)
                    krausOps[n] = local_getMatrix2FromFlatList(&params[1 + 2*2*2*n]);
                mixKrausMap(qureg, targs[0], krausOps, numKrausOps); // throws
            } 
            else if (numTargs == 2) {
                ComplexMatrix4 krausOps[16];
                for (int n=0; n < numKrausOps; n++)
                    krausOps[n] = local_getMatrix4FromFlatList(&params[1 + 2*4*4*n]);
                mixTwoQubitKrausMap(qureg, targs[0], targs[1], krausOps, numKrausOps); // throws
            }
        }
            break;
            
        case OPCODE_KrausNonTP: { ;
            int numKrausOps = (int) params[0];
            if (numTargs == 1) {
                ComplexMatrix2 krausOps[4];
                for (int n=0; n < numKrausOps; n++)
                    krausOps[n] = local_getMatrix2FromFlatList(&params[1 + 2*2*2*n]);
                mixNonTPKrausMap(qureg, targs[0], krausOps, numKrausOps); // throws
            } 
            else if (numTargs == 2) {
                ComplexMatrix4 krausOps[16];
                for (int n=0; n < numKrausOps; n++)
                    krausOps[n] = local_getMatrix4FromFlatList(&params[1 + 2*4*4*n]);
                mixNonTPTwoQubitKrausMap(qureg, targs[0], targs[1], krausOps, numKrausOps); // throws
            }
        }
            break;
            
        case OPCODE_G :
            if (!qureg.isDensityMatrix && params[0] != 0) {
                 // create factor exp(i param)
                Complex zero; zero.real=0; zero.imag=0;
                Complex fac; fac.real=cos(params[0]); fac.imag=sin(params[0]);
                setWeightedQureg(zero, qureg, zero, qureg, fac, qureg); // throws
            }
            break;
            
        case OPCODE_Fac : { ;
            Complex fac;    fac.real = params[0];  fac.imag = params[1];
            Complex zero;  zero.real = 0;          zero.imag = 0;
            if (fac.real == 0)
                extension_applyImagFactor(qureg, fac.imag);
            else if (fac.imag == 0)
                extension_applyRealFactor(qureg, fac.real);
            else
                setWeightedQureg(zero, qureg, zero, qureg, fac, qureg);
        }
            break;
            
        case OPCODE_Ph : { ;
            // unpack all controls and targets (since symmetric)
            // (ctrlCache has length [MAX_NUM_TARGS_CTRLS], so it can fit all targs)
            int* qubitCache = local_prepareCtrlCache(ctrls, numCtrls, -1);
            for (int i=0; i<numTargs; i++)
                qubitCache[numCtrls+i] = targs[i];
            // but attempt optimisations first
            int numQubits = numCtrls + numTargs;
            if (numQubits == 1)
                phaseShift(qureg, qubitCache[0], params[0]);
            else if (numQubits == 2)
                controlledPhaseShift(qureg, qubitCache[0], qubitCache[1], params[0]);
            else
                multiControlledPhaseShift(qureg, qubitCache, numQubits, params[0]);
        }
            break;
            
        default:            
            throw QuESTException("", "circuit contained an unknown gate (" + getOpcodeStr() + ")."); // throws
    }
}

void Gate::applyDaggerTo(Qureg qureg) {
    
    // validation performed within switch (often within inner applyTo call)
    
    switch(opcode) {
        
        // involutory gates
        case OPCODE_Id :
        case OPCODE_H :
        case OPCODE_SWAP :
        case OPCODE_X :
        case OPCODE_Y :
        case OPCODE_Z :
            applyTo(qureg); // throws
            break;

        // neg-param = inverse gates:
        case OPCODE_Rx :
        case OPCODE_Ry :
        case OPCODE_Rz :
        case OPCODE_R :
        case OPCODE_Ph :
        case OPCODE_G :
            params[0] *= -1;
            applyTo(qureg); // throws (safe to persist params mod)
            params[0] *= -1;
            break;
            
        // fac simply conjugates (params[1] = imaginary component) 
        case OPCODE_Fac :
            params[1] *= -1;
            applyTo(qureg); // throws (safe to persist params mod)
            params[1] *= -1;
            break;
            
        // gates with transposable matrices
        case OPCODE_U :
        case OPCODE_UNonNorm :
        case OPCODE_Matr :
            local_setFlatListToMatrixDagger(params, numTargs);
            applyTo(qureg); // throws (safe to persist params mod)
            local_setFlatListToMatrixDagger(params, numTargs);
            break;
        
        // name -> phase
        case OPCODE_S : { ;
            validate();
            int* ctrlCache = local_prepareCtrlCache(ctrls, numCtrls, targs[0]);
            multiControlledPhaseShift(qureg, ctrlCache, numCtrls+1, -M_PI/2); // throws
        }   
            break;
        case OPCODE_T : { ;
            validate();
            int* ctrlCache = local_prepareCtrlCache(ctrls, numCtrls, targs[0]);
            multiControlledPhaseShift(qureg, ctrlCache, numCtrls+1, -M_PI/4); // throws
        }
            break;
                        
        default:
            throw QuESTException("", "The dagger (conjugate transpose) of an operator (" + getOpcodeStr() + ") with no known dagger was requested."); // throws
    }
}

bool Gate::isUnitary() {
    
    switch(opcode) {
        
        case OPCODE_Id :
        case OPCODE_H :
        case OPCODE_SWAP :
        case OPCODE_X :
        case OPCODE_Y :
        case OPCODE_Z :
        case OPCODE_Rx :
        case OPCODE_Ry :
        case OPCODE_Rz :
        case OPCODE_R :
        case OPCODE_G :
        case OPCODE_S :
        case OPCODE_T :
        case OPCODE_Ph :
        case OPCODE_U :
        case OPCODE_UNonNorm : 
            return true;

        case OPCODE_M :
        case OPCODE_P :
        case OPCODE_Matr : 
        case OPCODE_Deph :
        case OPCODE_Depol :
        case OPCODE_Damp :
        case OPCODE_Kraus :
        case OPCODE_KrausNonTP :
            return false;
                  
        default:            
            throw QuESTException("", "an unrecognised gate (" + getOpcodeStr() + ") was queried for unitarity. This is likely an internal error."); // throws
    }
}

bool Gate::isPure() {
    
    if (isUnitary())
        return true;
    
    switch(opcode) {
        
        case OPCODE_M :
        case OPCODE_P :
        case OPCODE_Matr :
            return true;
        
        case OPCODE_Deph :
        case OPCODE_Depol :
        case OPCODE_Damp :
        case OPCODE_Kraus :
        case OPCODE_KrausNonTP :
            return false;
                  
        default:            
            throw QuESTException("", "an unrecognised gate (" + getOpcodeStr() + ") was queried for purity. This is likely an internal error."); // throws
    }
}

bool Gate::isInvertible() {
    
    if (isUnitary())
        return true;
        
    switch(opcode) {
        
        case OPCODE_P :
        case OPCODE_M :
            return false;
        
        case OPCODE_Matr :
            return local_isInvertible( local_getQmatrixFromFlatList(params, 1LL<<numTargs) );
        
        case OPCODE_Deph :
            if (numTargs == 1)
                return local_isNonZero(1 - 2*params[0]);
            if (numTargs == 2)
                return local_isNonZero(3 - 4*params[0]);
        
        case OPCODE_Depol :
            if (numTargs == 1)
                return local_isNonZero(3 - 4*params[0]);
            if (numTargs == 2)
                return local_isNonZero(15 - 16*params[0]);
        
        case OPCODE_Damp :
            if (numTargs == 1)
                return local_isNonZero(1 - params[0]);
        
        case OPCODE_Kraus :
        case OPCODE_KrausNonTP :
            return local_isInvertible( local_getKrausSuperoperatorFromFlatList(params, numTargs) );
                  
        default:            
            throw QuESTException("", "an unrecognised gate (" + getOpcodeStr() + ") was queried for invertibility. This is likely an internal error."); // throws
    }
}

void Gate::applyInverseTo(Qureg qureg) {
    
    if (!isInvertible())
        throw QuESTException("", "The inverse of a non-invertible operator (" + getOpcodeStr() + ") was requested. " 
            "This may be because the operator is always non-invertible (like a projector), or only non-invertible with "
            "its given parameters (for instance, because it is a maximally mixing channel)."); // throws
    
    if (isUnitary()) {
        applyDaggerTo(qureg); // throws
        return;
    }
    
    validate(); // throws
        
    switch (opcode) {
        
        case OPCODE_Matr : { ;
            qmatrix matr = local_getQmatrixFromFlatList(params, 1LL<<numTargs);
            qmatrix matrInv = local_getInverse(matr);
            
            local_setFlatListFromQmatrix(params, matrInv);
            applyTo(qureg); // throws (param mod doesn't matter)
            local_setFlatListFromQmatrix(params, matr);
        }
            return;
        
        case OPCODE_Deph :
            if (numTargs == 1) {
                qreal invParam = params[0] / (2*params[0] - 1);
                densmatr_mixDephasing(qureg, targs[0], 2*invParam);
            } else if (numTargs == 2) {
                qreal invParam = 3*params[0] / (4*params[0] - 3);
                ensureIndsIncrease(&targs[0], &targs[1]);
                densmatr_mixTwoQubitDephasing(qureg, targs[0], targs[1], (4*invParam)/3.);
            }
            return;
        
        case OPCODE_Depol :
            if (numTargs == 1) {
                qreal invParam = 3*params[0] / (4*params[0] - 3);
                densmatr_mixDepolarising(qureg, targs[0], (4*invParam)/3.);
            } else if (numTargs == 2) {
                qreal invParam = 15*params[0] / (16*params[0] - 15);
                ensureIndsIncrease(&targs[0], &targs[1]);
                densmatr_mixTwoQubitDepolarising(qureg, targs[0], targs[1], (16*invParam)/15.);
            }
            return;
        
        case OPCODE_Damp :
            if (numTargs == 1) {
                qreal invParam = params[0] / (params[0] - 1);
                densmatr_mixDamping(qureg, targs[0], invParam);
            }
            return;
                
        case OPCODE_Kraus :
        case OPCODE_KrausNonTP : { ;
            qmatrix superOp = local_getKrausSuperoperatorFromFlatList(params, numTargs);
            qmatrix superInv = local_getInverse(superOp);
            ComplexMatrixN superCM = createComplexMatrixN(2*numTargs);
            local_setMatrixNFromQmatrix(superCM, superInv);
            
            densmatr_applyMultiQubitKrausSuperoperator(qureg, targs, numTargs, superCM);
            destroyComplexMatrixN(superCM);
        }
            return;
                  
        default:            
            throw QuESTException("", "an internal error occurred. The inverse of an known invertible and non-unitary operator (" + getOpcodeStr() + ") could not be found."); // throws
    }
}

int Gate::getNumDecomps() {
    
    if (isPure())
        return 1;
        
    validate(); // throws
        
    switch(opcode) {
        
        case OPCODE_Damp : 
            return 2;
            
        case OPCODE_Deph :
            if (numTargs == 1)
                return 2;
            if (numTargs == 2)
                return 4;
                
        case OPCODE_Depol : 
            if (numTargs == 1)
                return 4;
            if (numTargs == 2)
                return 16;
        
        case OPCODE_Kraus :
        case OPCODE_KrausNonTP :
            return (int) params[0];
            
        default:
            throw QuESTException("", "An unrecognised gate (" + getOpcodeStr() + ") was queried for its number of decompositions into coherent operators.");
    }
}

qreal Gate::applyDecompTo(Qureg qureg, int decompInd) {
    
    if (qureg.isDensityMatrix)
        throw QuESTException("", "an internal error occurred. applyDecompTo() was called upon a density matrix."); // throws
                
    bool isRand = (decompInd == -1);    
    if (!isRand && decompInd >= getNumDecomps())
        throw QuESTException("", "an internal error occurred. applyDecompTo() was called with too large a decomposition index."); // throws

    if (isPure()) {
        applyTo(qureg); // throws
        return 1;
    }
    
    validate(); // throws
    
    switch(opcode) {
        
        case OPCODE_Damp : { ;
            
            if (params[0] < 0 || params[0] > 1)
                throw QuESTException("", "The probability of " + getOpcodeStr() + " is invalid.");
            
            int r = (isRand)? local_getRandomIndex(2) : decompInd;
            qreal s = sqrt(2.);

            // create one of the damping Kraus operators, times sqrt(2) (prob renormalising)
            ComplexMatrix2 m;
            m.real[0][0] = r*s;  m.real[0][1] = (!r)*s*sqrt(params[0]);
            m.real[1][0] = 0;    m.real[1][1] = r*s*sqrt(1-params[0]);
            m.imag[0][0] = 0;    m.imag[0][1] = 0;
            m.imag[1][0] = 0;    m.imag[1][1] = 0;
            
            applyMatrix2(qureg, targs[0], m); // throws
            return 1/2.;
        }
            
        case OPCODE_Deph : { ;
            qreal p = params[0];
            
            if (numTargs == 1) {
                
                if (p < 0)
                    throw QuESTException("", "The probability of 1-qubit " + getOpcodeStr() + " was negative."); // throws
                if (p > 1/2.)
                    throw QuESTException("", "The probability of 1-qubit " + getOpcodeStr() + " exceeded 1/2, at which maximal mixing occurs."); // throws
                
                // apply I or Z
                qreal probs[] = {1-p, p};
                int r = (isRand)? local_getRandomIndex(probs, 2) : decompInd;
                if (r == 1)
                    pauliZ(qureg, targs[0]); // throws
                    
                return probs[r];
            }
            else if (numTargs == 2) {
                
                if (p < 0)
                    throw QuESTException("", "The probability of 2-qubit " + getOpcodeStr() + " was negative."); // throws
                if (p > 3/4.)
                    throw QuESTException("", "The probability of 2-qubit " + getOpcodeStr() + " exceeded 3/4, at which maximal mixing occurs."); // throws
    
                // apply I, Z1, Z2, or Z1 Z2
                qreal probs[] = {1-p, p/3, p/3, p/3};
                int r = (isRand)? local_getRandomIndex(probs, 4) : decompInd;
                if (r == 1)
                    pauliZ(qureg, targs[0]); // throws
                if (r == 2)
                    pauliZ(qureg, targs[1]); // throws
                if (r == 3) {
                    pauliZ(qureg, targs[0]); // throws
                    pauliZ(qureg, targs[1]); // throws
                }
                
                return probs[r];
            }
        }
            break;
            
        case OPCODE_Depol : {
            qreal p = params[0];
            
            if (numTargs == 1) {
                
                if (p < 0)
                    throw QuESTException("", "The probability of 1-qubit " + getOpcodeStr() + " was negative."); // throws
                if (p > 3/4.)
                    throw QuESTException("", "The probability of 1-qubit " + getOpcodeStr() + " exceeded 3/4, at which maximal mixing occurs."); // throws
                
                // apply I, X, Y or Z
                qreal probs[] = {1-p, p/3, p/3, p/3};
                int r = (isRand)? local_getRandomIndex(probs, 4) : decompInd;
                if (r == 1)
                    pauliX(qureg, targs[0]); // throws
                if (r == 2)
                    pauliY(qureg, targs[0]); // throws
                if (r == 3)
                    pauliZ(qureg, targs[0]); // throws
                    
                return probs[r];
            }
            else if (numTargs == 2) {
                
                if (p < 0)
                    throw QuESTException("", "The probability of 2-qubit " + getOpcodeStr() + " was negative."); // throws
                if (p > 15/16.)
                    throw QuESTException("", "The probability of 2-qubit " + getOpcodeStr() + " exceeded 15/16, at which maximal mixing occurs."); // throws
                
                // apply I, X, Y or Z to either qubit (but I I has a different prob)
                qreal probs[16];
                probs[0] = 1-p;
                for (int i=1; i<16; i++)
                    probs[i] = p/15;
                    
                int r = (isRand)? local_getRandomIndex(probs, 16) : decompInd;
                int r0 = r / 4;
                int r1 = r % 4;
                
                if (r0 == 1)
                    pauliX(qureg, targs[0]); // throws
                if (r0 == 2)
                    pauliY(qureg, targs[0]); // throws
                if (r0 == 3)
                    pauliZ(qureg, targs[0]); // throws
                    
                if (r1 == 1)
                    pauliX(qureg, targs[1]); // throws
                if (r1 == 2)
                    pauliY(qureg, targs[1]); // throws
                if (r1 == 3)
                    pauliZ(qureg, targs[1]); // throws
                    
                return probs[r];
            }
        }
            break;
        
        case OPCODE_Kraus :
        case OPCODE_KrausNonTP : { ;
            int numOps = (int) params[0];
            int r = (isRand)? local_getRandomIndex(numOps) : decompInd;
            qreal fac = sqrt((qreal) numOps);
            
            // apply one of the Kraus maps, scaled by uniform probability
            if (numTargs == 1) {
                ComplexMatrix2 m = local_getMatrix2FromFlatListAtIndex(&params[1], r);
                local_setComplexMatrix2RealFactor(&m, fac);
                applyMatrix2(qureg, targs[0], m); // throws
                
            } else if (numTargs == 2) {
                ComplexMatrix4 m = local_getMatrix4FromFlatListAtIndex(&params[1], r);
                local_setComplexMatrix4RealFactor(&m, fac);
                applyMatrix4(qureg, targs[0], targs[1], m); // throws
            
            } else {
                ComplexMatrixN op = createComplexMatrixN(numTargs); // throws
                local_setMatrixNFromFlatListAtIndex(&params[1], op, numTargs, r);
                local_setComplexMatrixToRealFactor(op, fac);
                applyMatrixN(qureg, targs, numTargs, op); // throws
                destroyComplexMatrixN(op);
            }
            
            return 1/(qreal) numOps;
        }
            break;
            
        default:
            throw QuESTException("", "An unrecognised gate (" + getOpcodeStr() + ") was attemptedly applied through sampling.");
    }
    
    throw QuESTException("", "An internal error occurred during applyDecompTo(), likely relating to validation.");
}



/*
 * Circuit methods
 */
 
Gate Circuit::getGate(int ind) {
    return gates[ind];
}
 
int Circuit::getNumGates() {
    return numGates;
}

int Circuit::getTotalNumOutputs() {
    
    int n = 0;
    for (int i=0; i<numGates; i++)
        n += gates[i].getNumOutputs();
    
    return n;
}

int Circuit::getNumGatesWithOutputs() {
    
    int n = 0;
    for (int i=0; i<numGates; i++)
        if (gates[i].getNumOutputs() > 0)
            n++;
            
    return n;
}

bool Circuit::isUnitary() {
    
    for (int i=0; i<numGates; i++)
        if (! gates[i].isUnitary())
            return false;
            
    return true;
}

bool Circuit::isPure() {
    
    for (int i=0; i<numGates; i++)
        if (!gates[i].isPure())
            return false;
            
    return true;
}

void Circuit::applyTo(Qureg qureg, qreal* outputs, bool showProgress) {
    
    int outInd = 0;
    
    for (int gateInd=0; gateInd < numGates; gateInd++) {
        
        // halt if the user has tried to abort
        local_throwExcepIfUserAborted(); // throws
        
        // display progress to the user
        if (showProgress)
            local_updateCircuitProgress(gateInd / (qreal) numGates);

        // apply gate, optionally recording output
        Gate gate = gates[gateInd];
        qreal *outAddr = (outputs == NULL)? NULL : &outputs[outInd];
        gate.applyTo(qureg, outAddr); // throws
        outInd += gate.getNumOutputs();
    }
    
    // display progress to the user
    if (showProgress)
        local_updateCircuitProgress(1);
}

void Circuit::applySubTo(Qureg qureg, int startGateInd, int endGateInd) {
    
    for (int gateInd=startGateInd; gateInd < endGateInd; gateInd++)
        gates[gateInd].applyTo(qureg); // throws
}

void Circuit::applyDaggerSubTo(Qureg qureg, int startGateInd, int endGateInd) {
    
    for (int gateInd = endGateInd-1; gateInd >= startGateInd; gateInd--)
        gates[gateInd].applyDaggerTo(qureg); // throws
}

void Circuit::applyInverseSubTo(Qureg qureg, int startGateInd, int endGateInd) {
    
    for (int gateInd = endGateInd-1; gateInd >= startGateInd; gateInd--)
        gates[gateInd].applyInverseTo(qureg); // throws
}

qreal Circuit::applyDecompTo(Qureg qureg, long decompInd) {

    if (decompInd == -1) {
        
        for (int gateInd=0; gateInd < numGates; gateInd++)
            gates[gateInd].applyDecompTo(qureg); // throws
        
        return 0;

    } else {
        
        qreal prob = 1;

        for (int gateInd=0; gateInd < numGates; gateInd++) {
            Gate gate = gates[gateInd];
            int numDecomps = gate.getNumDecomps(); // throws
            
            prob *= gate.applyDecompTo(qureg, (int) (decompInd % numDecomps)); // throws
            decompInd /= (long) numDecomps;
        }
        
        return prob;
    }
}

long Circuit::getNumDecomps() {
    
    long numDecomps = 1;
    qreal logNumDecomps = 0;
    
    for (int gateInd = 0; gateInd < numGates; gateInd++) {
        
        int n = gates[gateInd].getNumDecomps(); // throws
        logNumDecomps += log2((qreal) n);
        
        if ((int) ceil(logNumDecomps) >= 63)    // bits in long
            throw QuESTException("", "overflow"); 
            
        numDecomps *= (long) n;
    }
    
    return numDecomps;
}

Circuit::~Circuit() {
    
    freeMMA();
    delete[] gates;
}



/*
 * interfacing 
 */

void internal_applyCircuit(int id, int storeBackup, int showProgress) {
    
    // load circuit description (local so no need to explicitly delete)
    Circuit circ;
    circ.loadFromMMA();
    
    // ensure qureg exists, else clean-up and exit
    // (must do this after loading from MMA so those packets are flushed)
    try {
        local_throwExcepIfQuregNotCreated(id); // throws
    } catch (QuESTException& err) {
        local_sendErrorAndFail("ApplyCircuit", err.message);
        return;
    }
    
    // optionally prepare a backup state
    Qureg qureg = quregs[id];
    Qureg backup;
    if (storeBackup)
        backup = createCloneQureg(qureg, env); // must later free
    
    // prepare gate output cache
    qreal* outputs = (qreal*) malloc(circ.getTotalNumOutputs() * sizeof *outputs);
    
    // attempt to apply circuit and send outputs to MMA
    try {
        circ.applyTo(qureg, outputs, showProgress); // throws
        
        circ.sendOutputsToMMA(outputs);
        
    // but if circuit application fails...
    } catch (QuESTException& err) {
        
        // restore backup (if made)
        if (storeBackup)
            cloneQureg(qureg, backup);
            
        // prepare error message
        std::string backupNotice;
        if (storeBackup)
             backupNotice = " The qureg (id " + std::to_string(id) + 
                ") has been restored to its prior state.";
        else
            backupNotice = " Since no backup was stored, the qureg (id " + std::to_string(id) + 
                ") is now in an unknown state, and should be reinitialised.";
        
        // send error to Mathematica
        if (err.thrower == "")
            local_sendErrorAndFail("ApplyCircuit", err.message + backupNotice);
        else if (err.thrower == "Abort")
            local_sendErrorAndAbort("ApplyCircuit", err.message + backupNotice);
        else 
            local_sendErrorAndFail("ApplyCircuit", 
                "Error in " + err.thrower + ": " + err.message + backupNotice);
    }
    
    // clean-up regardless of error state
    free(outputs);
    if (storeBackup)
        destroyQureg(backup, env);
}

void internal_sampleExpecPauliString(int showProgress, int initQuregId, int workId1, int workId2) {
    
    // precondition: both or neither of workId1 and workId2 are -1, 
    //      to indicate no working registers were passed
    
    
    // samples is a positive integer, or a flag to instead use deterministic method
    long numSamples;
    WSGetLongInteger(stdlink, &numSamples);
    bool useAllDecomps = (numSamples == -1);
    
    // load circuit description (local so no need to explicitly delete)
    Circuit circ;
    circ.loadFromMMA();
    
    // load Hamiltonian from MMA (and also validate quregId), must later free
    PauliHamil hamil;
    try {
        hamil = local_loadPauliHamilForQuregFromMMA(initQuregId); // throws
    
    } catch (QuESTException& err) {
        
        local_sendErrorAndFail("SampleExpecPauliString", err.message);
        return;
    }
        
    // fetch quregs
    Qureg initQureg = quregs[initQuregId];
    int numQb = initQureg.numQubitsRepresented;
    
    Qureg workState1;
    Qureg workHamil2;
    
    long maxNeededSamples;
    bool maxNeededOverflowed;
    
    // validate quregs, circuit and other params
    try {
        if (!useAllDecomps && numSamples <= 0)
            throw QuESTException("", "The number of samples must be a positive integer."); // throws
        
        if (initQureg.isDensityMatrix)
            throw QuESTException("", "The initial qureg must be a state-vector."); // throws
        
        // optionally create new working registers
        if (workId1 == -1) {
            workState1 = createQureg(initQureg.numQubitsRepresented, env);
            workHamil2 = createQureg(initQureg.numQubitsRepresented, env);
        }
        
        // otherwise validate given registers
        else {
            if (workId1 == workId2 || workId1 == initQuregId || workId2 == initQuregId)
                throw QuESTException("", "The working quregs must be unique, and cannot be the initial qureg."); // throws
            
            local_throwExcepIfQuregNotCreated(workId1); // throws
            local_throwExcepIfQuregNotCreated(workId2); // throws
            workState1 = quregs[workId1];
            workHamil2 = quregs[workId2];
            
            if (workState1.isDensityMatrix || workHamil2.isDensityMatrix)
                throw QuESTException("", "The working quregs must be statevectors."); // throws

            if (workState1.numQubitsRepresented != numQb || workHamil2.numQubitsRepresented != numQb)
                throw QuESTException("", "The working quregs must have the same number of qubits as the initial qureg."); // throws
        }
        
        // if above is successful, obtain num messages needed
        try {
            maxNeededSamples = circ.getNumDecomps(); // throws
            maxNeededOverflowed = false;
        }
        catch (QuESTException& err) {
            // but if we overflowed, attempt to gracefully continue
            if (err.message == "overflow") {
                maxNeededSamples = -1;
                maxNeededOverflowed = true;
                if (useAllDecomps)
                    throw QuESTException("", "The number of unique circuit decompositions is too large to be enumerated (exceeds 2^63). A smaller number of samples must be specified."); // throws
            }
            // and rethrow all other errors (triggered by circuit validation)
            else {
                throw;
            }
        }
        
    } catch (QuESTException& err) {
    
        local_sendErrorAndFail("SampleExpecPauliString", err.message);
        local_freePauliHamil(hamil);
        return;
    }
    
    // if gratuitously many samples requested, switch to deterministic simulation
    if (!useAllDecomps &&!maxNeededOverflowed && numSamples >= maxNeededSamples) {
        local_sendWarningAndContinue("SampleExpecPauliString",
            "As many or more samples were requested than there are unique decompositions of the circuit "
            "(of which there are " + std::to_string(maxNeededSamples) + "). "
            "Proceeding instead with deterministic simulation of each decomposition in-turn. "
            "Hide this warning by setting the number of samples to All, or using Quiet[].");
        
        useAllDecomps = true;
    }
    
    if (useAllDecomps)
        numSamples = maxNeededSamples;
    
    // attempt to sample the expected value
    try {
        qreal expecValSum = 0;
        qreal compen = 0;
        
        for (long n=0; n<numSamples; n++) {
            
            // halt if the user has tried to abort (casues ~x5 slowdown)
            local_throwExcepIfUserAborted(); // throws
            
            // display progress to the user
            if (showProgress)
                local_updateCircuitProgress(n / (qreal) numSamples);
            
            cloneQureg(workState1, initQureg);

            qreal fac = 1;
            if (useAllDecomps)
                fac = circ.applyDecompTo(workState1, n); // throws
            else
                circ.applyDecompTo(workState1); // throws
                            
            qreal sample = fac * calcExpecPauliHamil(workState1, hamil, workHamil2); // throws
            
            // aggregate through Kahan summation, to mitigate numerical error
            qreal tmp1 = sample - compen;
            qreal tmp2 = expecValSum + tmp1;
            compen = (tmp2 - expecValSum) - tmp1;
            expecValSum = tmp2;
        }
        
        // output average energy (if random), else determined energy
        qreal expecVal = expecValSum / ((useAllDecomps)? 1 : numSamples);
        WSPutReal64(stdlink, expecVal);
        
    } catch (QuESTException& err) {
    
        local_sendErrorAndFail("SampleExpecPauliString", err.message);
    } 
    
    // clean-up even if above errors
    local_freePauliHamil(hamil);
    if (workId1 == -1) {
        destroyQureg(workState1, env);
        destroyQureg(workHamil2, env);
    }
}
