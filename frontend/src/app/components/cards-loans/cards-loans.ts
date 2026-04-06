import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

@Component({
  selector: 'app-cards-loans',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './cards-loans.html',
  styleUrl: './cards-loans.scss'
})
export class CardsLoansComponent implements OnInit {
  private apiService = inject(ApiService);

  cards: any[] = [];
  loans: any[] = [];
  banks: any[] = [];
  familyMembers: any[] = [];

  newCard = {
    bank_id: null,
    card_name: '',
    owner: '',
    last_four_digits: '',
    card_type: 'Débito',
    credit_limit: 0,
    current_debt: 0,
    available_balance: 0
  };

  newLoan = {
    bank_id: null,
    description: '',
    owner: '',
    initial_amount: 0,
    total_installments: 1,
    pending_installments: 1,
    monthly_payment: 0,
    interest_rate: 0,
    start_date: new Date().toISOString().split('T')[0]
  };

  loadingCard = false;
  loadingLoan = false;
  successMsg = '';
  errorMsg = '';

  ngOnInit() {
    this.loadData();
  }

  loadData() {
    this.apiService.getCards().subscribe(data => this.cards = data);
    this.apiService.getLoans().subscribe(data => this.loans = data);
    this.apiService.getBanks().subscribe(data => this.banks = data);
    this.apiService.getFamilyMembers().subscribe(data => this.familyMembers = data);
  }

  onCreateCard() {
    this.loadingCard = true;
    this.apiService.createCard(this.newCard).subscribe({
      next: () => {
        this.successMsg = 'Tarjeta registrada correctamente';
        this.resetCardForm();
        this.loadData();
        this.loadingCard = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = 'Error al registrar la tarjeta';
        this.loadingCard = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onCreateLoan() {
    this.loadingLoan = true;
    this.apiService.createLoan(this.newLoan).subscribe({
      next: () => {
        this.successMsg = 'Préstamo registrado correctamente';
        this.resetLoanForm();
        this.loadData();
        this.loadingLoan = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = 'Error al registrar el préstamo';
        this.loadingLoan = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  resetCardForm() {
    this.newCard = {
      bank_id: null,
      card_name: '',
      owner: '',
      last_four_digits: '',
      card_type: 'Débito',
      credit_limit: 0,
      current_debt: 0,
      available_balance: 0
    };
  }

  resetLoanForm() {
    this.newLoan = {
      bank_id: null,
      description: '',
      owner: '',
      initial_amount: 0,
      total_installments: 1,
      pending_installments: 1,
      monthly_payment: 0,
      interest_rate: 0,
      start_date: new Date().toISOString().split('T')[0]
    };
  }
}
