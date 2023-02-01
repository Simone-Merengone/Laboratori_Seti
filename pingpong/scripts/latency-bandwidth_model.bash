#!/bin/bash

# Se l'utente inserisce dei parametri dopo la chiamata dello script, esso non parte
if [[ $# != 0 ]]; then
	printf "Error: Unexpected parameters\n";
	exit 1;
fi
# -e si usa per abilitare l'interpretazione di caratteri speciali per echo (\n, \t)
set -e

# Dichiariamo un array per poter avere più facilità nella creazione dei grafici
declare -a protocol=("udp" "tcp")

# Prepariamo due variabili per i Throughput medi in due istanti di tempo diversi
declare Thput1
declare	Thput2

# Prepariamo due variabili per salvare la dimensione dei messaggi in due istanti di tempo diversi
declare minMessSize
declare maxMessSize

# Facciamo un ciclo che crei due plot usando gli elementi di protocol (udp e tcp)
for indexProtocol in "${protocol[@]}"
do
	# Recupero l'infomazione all'inizio ed alla fine dei file *_throughput.dat, eliminando i dati che non mi servono
	Thput1=$(head -n 1 ../data/"${indexProtocol}"_throughput.dat | cut -d ' ' -f3) # cut scritto in questo modo usa ' ' come delimitatore fra gli elementi della stringa, dopodichè scegliamo l'elemento da mantenere (in questo caso f3)
	Thput2=$(tail -n 1 ../data/"${indexProtocol}"_throughput.dat | cut -d ' ' -f3)

	# Stesso ragionamento
	minMessSize=$(head -n 1 ../data/"${indexProtocol}"_throughput.dat | cut -d ' ' -f1)
	maxMessSize=$(tail -n 1 ../data/"${indexProtocol}"_throughput.dat | cut -d ' ' -f1)


	# Usato per eliminare la notazione scientifica (es e.78998e+06)
	declare exponent

	# Eliminazione esponenziali (da terminare)
	if [[ $Thput2 == *"e+"* ]]; then
		exponent=$(echo $Thput2 | cut -d '+' -f2)	
		Thput2=$(echo $Thput2 | cut -d 'e' -f1)

		Thput2=$(echo "$Thput2*(10^$exponent)" | bc)
	fi

    echo  
    echo ----"$indexProtocol"----
    echo Size Min: "$minMessSize" 
    echo Size Max: "$maxMessSize"
    echo Throughput Min: "$Thput1"
    echo Throughput Max: "$Thput2"
    
    echo Test Esponente: "$exponent"


	# Dichiaro ritardo min e max, e vi calcolo al suo interno il delay usando la formula inversa "delay = msg_size/T"
	# bc è una calcolatrice utilizzabile da terminale, ed ha la facoltà di decidere la scala da usare, bisogna definire le variabili (ed il loro valore) per poi usarli nel calcolo finale
	declare minDelay
	declare maxDelay
	
	minDelay=$(echo "scale=10; $minMessSize/$Thput1" | bc)
	maxDelay=$(echo "scale=10; $maxMessSize/$Thput2" | bc)

	
	echo Delay Min: "$minDelay"
    echo Delay Max: "$maxDelay"
	
	
	# Dichiaro le variabili myLatency0 e myBandwidth secondo le formule definite su aulaweb
	declare myL0
	declare myB
	myL0=$(echo "scale=10; ((($minDelay*$maxMessSize)-($maxDelay*$minMessSize))/($maxMessSize-$minMessSize))" | bc)
	myB=$(echo "scale=5; (($maxMessSize-$minMessSize)/($maxDelay-$minDelay))" | bc)
	
	
	echo myLatency0: "$myL0"
	echo myB: "$myB"
	
	
	# Mi premuro di cancellare vecchi grafici nel caso ci siano
	if test -f "${indexProtocol}_latency-bandwidth_model.png"; then
		rm "${indexProtocol}_latency-bandwidth_model.png"
	fi
	
	# Creo il plot lbf() è il calcolo per il modello Banda-Latenza = "D(n) = L0 + N/B" => "x / ($myL0 + x / $myB)"
	gnuplot <<-eNDgNUPLOTcOMMAND
        set term png size 900, 800 
        set output "../data/${indexProtocol}_banda_latenza.png"
        set logscale y 1
        set logscale x 1
        set xlabel "msg size (B)"
        set ylabel "throughput (KB/s)"
        lbf(x) = x / ($myL0 + x / $myB)
        plot "../data/${indexProtocol}_throughput.dat" using 1:3 title "${indexProtocol} ping-pong Throughput" \
            with linespoints, \
        lbf(x) title "Latency-Bandwidth model with L=${myL0} and B=${myB}" \
            with linespoints
        clear
eNDgNUPLOTcOMMAND

done
