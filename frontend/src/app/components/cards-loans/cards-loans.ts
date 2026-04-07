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
  editingCardId: number | null = null;
  editingLoanId: number | null = null;

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

  onSubmitCard() {
    this.loadingCard = true;
    const request = this.editingCardId === null
      ? this.apiService.createCard(this.newCard)
      : this.apiService.updateCard(this.editingCardId, this.newCard);

    request.subscribe({
      next: () => {
        this.successMsg = this.editingCardId === null
          ? 'Tarjeta registrada correctamente'
          : 'Tarjeta actualizada correctamente';
        this.resetCardForm();
        this.loadData();
        this.loadingCard = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = this.editingCardId === null
          ? 'Error al registrar la tarjeta'
          : 'Error al actualizar la tarjeta';
        this.loadingCard = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onSubmitLoan() {
    this.loadingLoan = true;
    const request = this.editingLoanId === null
      ? this.apiService.createLoan(this.newLoan)
      : this.apiService.updateLoan(this.editingLoanId, this.newLoan);

    request.subscribe({
      next: () => {
        this.successMsg = this.editingLoanId === null
          ? 'Préstamo registrado correctamente'
          : 'Préstamo actualizado correctamente';
        this.resetLoanForm();
        this.loadData();
        this.loadingLoan = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = this.editingLoanId === null
          ? 'Error al registrar el préstamo'
          : 'Error al actualizar el préstamo';
        this.loadingLoan = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onEditCard(card: any) {
    this.editingCardId = card.id;
    this.newCard = {
      bank_id: card.bank_id ?? null,
      card_name: card.card_name ?? '',
      owner: card.owner ?? '',
      last_four_digits: card.last_four_digits ?? '',
      card_type: card.card_type ?? 'Débito',
      credit_limit: card.credit_limit ?? 0,
      current_debt: card.current_debt ?? 0,
      available_balance: card.available_balance ?? 0
    };
  }

  onDeleteCard(card: any) {
    if (!confirm(`¿Deseas eliminar la tarjeta "${card.card_name}"?`)) {
      return;
    }

    this.apiService.deleteCard(card.id).subscribe({
      next: () => {
        if (this.editingCardId === card.id) {
          this.resetCardForm();
        }
        this.successMsg = 'Tarjeta eliminada correctamente';
        this.loadData();
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = 'Error al eliminar la tarjeta';
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onEditLoan(loan: any) {
    this.editingLoanId = loan.id;
    this.newLoan = {
      bank_id: loan.bank_id ?? null,
      description: loan.description ?? '',
      owner: loan.owner ?? '',
      initial_amount: loan.initial_amount ?? 0,
      total_installments: loan.total_installments ?? 1,
      pending_installments: loan.pending_installments ?? 1,
      monthly_payment: loan.monthly_payment ?? 0,
      interest_rate: loan.interest_rate ?? 0,
      start_date: loan.start_date ?? new Date().toISOString().split('T')[0]
    };
  }

  onDeleteLoan(loan: any) {
    if (!confirm(`¿Deseas eliminar el préstamo "${loan.description}"?`)) {
      return;
    }

    this.apiService.deleteLoan(loan.id).subscribe({
      next: () => {
        if (this.editingLoanId === loan.id) {
          this.resetLoanForm();
        }
        this.successMsg = 'Préstamo eliminado correctamente';
        this.loadData();
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = 'Error al eliminar el préstamo';
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  resetCardForm() {
    this.editingCardId = null;
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
    this.editingLoanId = null;
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
