#############################################################################
# Projeto Planejamento Estrategico Hospital (Risoleta Neves)
# Trabalho final da disciplina Pesquisa Operacional para Saúde 2025/1
# Versao 1: 30/04/2025
# Versão 2: 05/06/2025 por Naiara Helena Vieira
# Naiara Helena Vieira, aluna de doutorado PPGEP
# Autor (professor orientador): João Flávio de Freitas Almeida <joao.flavio@dep.ufmg.br>
# LEPOINT: Laboratório de Estudos em Planejamento de Operações Integradas
# Departamento de Engenharia de Produção
# Universidade Federal de Minas Gerais - Escola de Engenharia
############################################################################# 

# Comando para rodar esse modelo: 
# glpsol -m hrtn_modelo.mod -d hrtn_data.dat -d hrtn_cidades.dat --mipgap 0.01 --cuts


# Conjunto das cidades e regioes atendidas pelo HRTN
set I; 

# Nome dos Municipios
param Mun{I} symbolic;

# Populacao dos Municipios, de acordo com IBGE
param POP{I} integer, >= 0;

# Latitude dos municipios
param lat{I};

# Longitude dos municipios
param lng{I};

set R; # 1..67; Set of resource types 
param R_Qty{R};
param R_Description{R} symbolic;

set SL within R;    # Sala 
set EQ within R;    # Equipamento 
set LT within R;    # Leito 
set PF within R;    # Profissionais  
set MD within R;    # Medicos 
set INF := SL union EQ union LT;    # Recursos com custo fixo: Infraestrutura
set TE := PF union MD;             # Recursos com custo fixo: Team 

set S; # 1..56; Set of service types 

set P; # Types of Patients SUS (Manchester Protocol) 

set K; # CAPEX (Capital Expenditure - Investments) 

# Reserva: Description of Investment Classes
param RESE{K} symbolic; 

# Average salary of team of professionals CBO r
#param SM{TE}, >= 0;

# Factor mult. for Staff on Salary
# How much the Personal Item is more expensive than  the base salary
#param FPS:= 2.1;

# Average annual salary of professionals r
#param SMA{r in TE}:= 12*SM[r]*FPS, >= 0;

# Salary adjustment for the professional category r
#param AS{TE}, >=0, default 1.05;

# Investment resource for next year - CAPEX
param RPA{K};
check sum{k in K}RPA[k] >= 1-1E-9; # Percentage of Investment for next year
check sum{k in K}RPA[k] <= 1+1E-9; # Percentage of Investment for next year

#param PROP_FP:= 0.80;   # Employee-day/patient-day ratio (year)
#param ALOS{S}, default 1; # Average Lenght of stay 

# Set of resources required to serve demand for service s in S 
set RS{S} within R; 

# param TUN{S};     # Tempo unitário (h) 
param TUR{s in S, r in R: r in RS[s]}; # # Tempo unitário por serviço e recurso(h)
param PSUS{S};    # Preco SUS
param VC{S}, >=0, <= 1; # Custo Variável (% do preço) 
param DMAXKM{S};  # Deslocamento maximo de paciente (km) 
param DMAXMIN{S}; # Deslocamento maximo de paciente (min)
param NEED{S};    # Necessidade em saúde (serviço / 1000 hab) 
param OFFER{S};   # Oferta do serviço em % da população 
param S_min{S};     # Producao minima (qualidade e escala)
param S_description{S} symbolic; # Descricao alinhada ao Plano Operativo Anual Hospitalar

# Distance (km) from Origin (municipality or even within BH) to HRTN
param DIST{i in I}, >= 0; 
param DUR{i in I}, >= 0;

set Lk dimen 2:= setof{i in I, s in S: DIST[i] <= DMAXKM[s]}(s,i);
set H{s in S}:= setof{i in I: DIST[i] <= DMAXKM[s]} i;


# (Need) requirements for service s and municipality i
# (Referred + Spontaneous) demand.
# Operations is coordinated with other points in the health network
param N{s in S, i in H[s]}:= (NEED[s]/1000)*POP[i]; 

# (Offer) Supply of service s at municipality i
# e.g. CNES: Number of health workforce teams at municipality i (professionals)
# Number  of ICU, RPA, clinical and Surgical beds per municipality i
# Number of hospital labs per municipality i;
# Number of drugstore withing hospitals per municipality i.
# SP/SADT (Serviços Profissionais / Serviço Auxiliar Diagnóstico e. Terapia)
param O{s in S, i in I}:= OFFER[s]*POP[i]; # However, in the DEM it is "i in H", which is good.

# (demand) Population of origin i, requiring service s (31.560 data)
param DEM{s in S, i in H[s]}:= max(0,N[s,i]-O[s,i]);

# Market (MKT) share of hospital services in municipality i
param MKT{i in I}, >= 0, <= 1;

# Decreased "attractiveness" function: Decreased function of travel time (or dist)
check{s in S, i in H[s]}: DIST[i] <= DMAXKM[s];
param Beta{S}, <= 1; # Nivel de Decaimento da demanda
param SIGMA{s in S, i in H[s]} := exp(-Beta[s]*DIST[i]);


# Fixed cost for resource use per period    ($/year) or ($/month)
param FC{r in R}; 
param BigM:= 1e+3;

# Types of Patients SUS (Manchester Protocol) 
param MANCH{p in P}, >=0, <= 1; 
check sum{p in P}MANCH[p] <= 1+1e-6;

# Revenue per service type s and origin p
param PRICE{s in S};

# Certificação de Entidades Beneficentes de Assistência Social na Área de Saúde
# Desconto 30% com : (25%) INSS, (12%) PIS/COFINS e IRPJ
# Hospital Filantropico
param CEBAS_P:=0.25; # pessoal
param CEBAS_O:=0.12; # operação


# If (demand) population of origin i requiring service s 
# is selected or not 
var x{s in S, i in H[s]}, binary; 

# Capacity for service s (population) (decision) 
var q{S}, >=0, integer; 

# Amount/quantity of resource r (decision) 
var w{R}, >=0, integer; 
var wb{R}, binary; # If resource is used (Fixed Costs) 

# Booking/reserve for the following year for category k
var z{K}, >= 0;

# Demand assigned will set the services capacity: 
# A hospital provides a sum of services ...
# Service (hours of Service) <= Service (hours of Service)
s.t. R1{s in S}: sum{i in I: i in H[s]}DEM[s,i]*SIGMA[s,i]*MKT[i]*x[s,i] <= q[s];

# ... However, a hospital is not a sum of services, but a 
# a sum of resources that provide the services. 
# Resource <= Resource
# (% of Resource / hours of Service) * hours of Service  <= Resource
# FTE (Full Time Equivalent) per year 
# (40h/week * 4.25 weeks/month * 12 months/year)
param FTE_A:= 40*4.25*12; 

s.t. R2{r in R}: sum{s in S: r in RS[s]}TUR[s,r]*q[s] <= FTE_A*w[r];

# Minimum workload for service s economic feasibility and quality
# hours of Service >= Service
s.t. R3{s in S}: q[s] >= min(sum{i in I: i in H[s]}DEM[s,i]*SIGMA[s,i]*MKT[i],S_min[s]);

# s.t. R4{r in R}: w[r] <= wb[r]*BigM;

#3 - Reservations for the following year - New equipment and works will be required. 
# A contingency fund for emergencies is also desirable
param CAPEX:= 0.04; # Percentage for Capital Expenditure (CAPEX) for the following year
s.t. R5{k in K}: z[k] >= RPA[k]*(CAPEX*(sum{s in S, p in P, i in H[s]}PRICE[s]*MANCH[p]*(DEM[s,i]*SIGMA[s,i]*MKT[i])*x[s,i]));
s.t. R6: sum{k in K} z[k] >= CAPEX*(sum{s in S, p in P, i in H[s]}PRICE[s]*MANCH[p]*(DEM[s,i]*SIGMA[s,i]*MKT[i])*x[s,i]);

maximize PROFIT:
    # Revenue per service type s and origin p
    sum{s in S, p in P, i in H[s]}PRICE[s]*MANCH[p]*(DEM[s,i]*SIGMA[s,i]*MKT[i])*x[s,i]
    #  Variable cost of services s (per patient: service types s..: workforce, lab, drugstore)
    - (sum{s in S, p in P}((PRICE[s]*MANCH[p]*(VC[s]-CEBAS_O))*q[s]))
    # Fixed Cost of resources for such services (beds, equipment)
    - (12*sum{r in INF}FC[r]*w[r] + 12*sum{r in TE}(1-CEBAS_P)*FC[r]*w[r])
    # New investments for the following year
    - sum{k in K}z[k];

solve;

printf: "\n==========================================================================\n";
printf: "Dimensionamento Hospital Media e Alta Complexidade Risoleta Neves - MG\n";
printf: "==========================================================================\n";
printf: "%-20s ($):\t%15.2f\n", "Receita SUS", (sum{s in S, p in P, i in H[s]}PRICE[s]*MANCH[p]*(DEM[s,i]*SIGMA[s,i]*MKT[i])*x[s,i]);
printf: "%-20s ($):\t%15.2f\n", "Receita Incentivo", 242558435.75;
printf: "%-20s ($):\t%15.2f\n", "Custo Fixo", 12*sum{r in INF}FC[r]*w[r] + 12*sum{r in TE}(1-CEBAS_P)*FC[r]*w[r];
printf: "%-20s ($):\t%15.2f\n", "Custo Variavel", sum{s in S, p in P}((PRICE[s]*MANCH[p]*(VC[s]-CEBAS_O))*q[s]);
printf: "%-20s ($):\t%15.2f\n", "Reserva CAPEX", sum{k in K}z[k];
printf: "%-20s ($):\t%15.2f\n", "Recursos a investir", PROFIT+242558435.75;
printf: "==========================================================================\n\n";

printf"====================================================================\n";
printf "%-24s:\t\t%-10s", "Categorias de Reserva", "Total ($)";
printf"\n====================================================================\n";
printf{k in K}: "%-20s ($):\t%15.2f\n", RESE[k], z[k];
printf"--------------------------------------------------------------------\n";
printf "%-20s ($):\t%15.2f\n", "Sub-total", sum{k in K}z[k];
printf"====================================================================\n"; 

printf: "==========================================================================\n";
printf: "Selecao de atendimento de demanda \n";
printf: "==========================================================="; 
printf: "===========================================================\n";
printf: "%-5s\t%-10s\t%-10s\t%-10s\t%-10s\t%-4s\t%-10s\t%-8s\t%-20s\n", 
"Serv.", "Munic.", "Necess", "Ofert.", "Demanda", "MKT", 
"Atend.", "Perc.(%)", "Municipio";
printf: "==========================================================="; 
printf: "===========================================================\n";
printf {s in S, i in H[s]: x[s,i] > 0}:
"%-7s\t%-10s:\t%8d\t%8d\t%8d\t%4d%%\t%8d\t%6d%%\t\t%-20s\n", 
s, i, N[s,i], O[s,i], DEM[s,i]*SIGMA[s,i], MKT[i]*100,
DEM[s,i]*SIGMA[s,i]*MKT[i]*x[s,i], 
((DEM[s,i]*SIGMA[s,i]*MKT[i]*x[s,i])/(DEM[s,i]*SIGMA[s,i]*MKT[i]))*100,Mun[i];
printf: "==========================================================="; 
printf: "===========================================================\n";

printf: "==========================================================="; 
printf: "===========================================================\n";
printf: "%-5s\t%-7s\t\t%-7s\t\t%-7s\t\t%-7s\t\t%-20s\n", 
"Serv.", "Demanda", "Minimo", "Atend.", "Perc(%)", "Descricao";

printf: "==========================================================="; 
printf: "===========================================================\n";
printf {s in S: q[s]>0}:"%-5s:\t%7d\t\t%7d\t\t%7d\t\t%6d%%\t\t%-s\n", s, 
sum{i in H[s]}DEM[s,i]*SIGMA[s,i]*MKT[i], S_min[s], q[s], 
(max(0,q[s]/(sum{i in H[s]}DEM[s,i]*SIGMA[s,i]*MKT[i]-1e-6)))*100,
S_description[s];
printf: "==========================================================="; 
printf: "===========================================================\n";

printf: "==========================================================="; 
printf: "===========================================================\n";
printf: "%-5s\t%-10s\t%-12s\t%-12s\t%-20s\n", 
"Recurso", "Quantidade", "C. Unit($)", "Custo ($)", "Descricao";
printf: "==========================================================="; 
printf: "===========================================================\n";
printf {r in R: w[r]>0}:"%-5s:\t%10d\t%12.2f\t%12.2f\t%-20s\n", 
r, w[r], FC[r], FC[r]*w[r], R_Description[r];
printf"----------------------------------------------------------------------------------------------\n";
printf "Sub-total ($):\t\t\t\t%12.2f\n", sum{r in R}FC[r]*w[r];
printf: "==========================================================="; 
printf: "===========================================================\n";


end;

